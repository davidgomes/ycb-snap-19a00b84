defmodule ObanChoreWeb.DashboardLiveTest do
  use ExUnit.Case, async: false
  use Oban.Testing, repo: ObanChore.Test.Repo

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias ObanChore.Test.Chores.{UniqueCleanup, UserBackfill}
  alias ObanChore.Test.{PubSub, Repo}

  @endpoint ObanChore.Test.Endpoint

  setup do
    owner = Ecto.Adapters.SQL.Sandbox.start_owner!(Repo, shared: true)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(owner) end)

    start_supervised!(
      {ObanChore.Plugin, chores: [UserBackfill, UniqueCleanup], pubsub_server: PubSub}
    )

    {:ok, conn: build_conn()}
  end

  describe "mount" do
    test "lists the configured chores", %{conn: conn} do
      {:ok, view, html} = live(conn, "/chores")

      assert html =~ "No chore selected"
      assert has_element?(view, chore_button(UserBackfill), "User Backfill")
      assert has_element?(view, chore_button(UniqueCleanup), "Unique Cleanup")
    end

    test "shows counts and tabs for jobs that are already active", %{conn: conn} do
      %{id: first_id} = Oban.insert!(UserBackfill.new(%{user_id: 1}))
      %{id: second_id} = Oban.insert!(UserBackfill.new(%{user_id: 2}))

      {:ok, view, _html} = live(conn, "/chores")

      assert view |> element(chore_button(UserBackfill) <> " .oc-badge") |> render() =~ "2"
      refute has_element?(view, chore_button(UniqueCleanup) <> " .oc-badge")

      select_chore(view, UserBackfill)

      assert has_element?(view, job_tab(first_id), "Job ##{first_id}")
      assert has_element?(view, job_tab(second_id), "Job ##{second_id}")
    end
  end

  describe "selecting a chore" do
    test "shows its description and form", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chores")

      html = select_chore(view, UserBackfill)

      assert html =~ "Backfills data for a single user."
      assert has_element?(view, chore_button(UserBackfill) <> ".oc-nav-item--active")
      assert has_element?(view, visible_chore(UserBackfill) <> " input[name='args[user_id]']")
      assert has_element?(view, visible_chore(UserBackfill) <> " input[value='Manual run']")
      refute has_element?(view, visible_chore(UniqueCleanup))
    end

    test "falls back to a generic subtitle without a description", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chores")

      assert select_chore(view, UniqueCleanup) =~ "Configure and execute this chore."
    end

    test "worker-level uniqueness disables the unique toggle", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chores")

      select_chore(view, UserBackfill)
      refute has_element?(view, unique_toggle(UserBackfill) <> "[disabled]")

      html = select_chore(view, UniqueCleanup)
      assert has_element?(view, unique_toggle(UniqueCleanup) <> "[disabled]")
      assert html =~ "Uniqueness is enforced by the worker definition."
    end
  end

  describe "validation" do
    test "renders changeset errors on change", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chores")
      select_chore(view, UserBackfill)

      assert view |> chore_form(UserBackfill, %{user_id: ""}) |> render_change() =~
               "can&#39;t be blank"

      assert view |> chore_form(UserBackfill, %{user_id: "-1"}) |> render_change() =~
               "must be greater than 0"
    end

    test "does not enqueue invalid submissions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chores")
      select_chore(view, UserBackfill)

      assert view |> chore_form(UserBackfill, %{user_id: "0"}) |> render_submit() =~
               "must be greater than 0"

      refute_enqueued(worker: UserBackfill)
    end
  end

  describe "executing a chore" do
    test "enqueues a job and switches to its tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chores")
      select_chore(view, UserBackfill)

      view |> chore_form(UserBackfill, %{user_id: "42"}) |> render_submit()

      assert_enqueued(worker: UserBackfill, args: %{user_id: 42, reason: "Manual run"})
      [%{id: job_id}] = all_enqueued(worker: UserBackfill)

      html = render(view)
      assert html =~ "Successfully enqueued User Backfill"
      assert has_element?(view, job_tab(job_id) <> ".oc-tab-item--active")
      assert has_element?(view, "[data-job-id='#{job_id}'].oc-block", "42")
      refute has_element?(view, visible_chore(UserBackfill))
    end

    test "tabs switch between the form and job details", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chores")
      select_chore(view, UserBackfill)
      view |> chore_form(UserBackfill, %{user_id: "42"}) |> render_submit()
      [%{id: job_id}] = all_enqueued(worker: UserBackfill)

      view |> element("button[phx-value-tab='new']") |> render_click()
      assert has_element?(view, visible_chore(UserBackfill))
      refute has_element?(view, "[data-job-id='#{job_id}'].oc-block")

      view |> element(job_tab(job_id)) |> render_click()
      assert has_element?(view, "[data-job-id='#{job_id}'].oc-block")
      refute has_element?(view, visible_chore(UserBackfill))
    end

    test "streams logs and status updates while the job runs", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chores")
      select_chore(view, UserBackfill)
      view |> chore_form(UserBackfill, %{user_id: "42"}) |> render_submit()
      [%{id: job_id}] = all_enqueued(worker: UserBackfill)

      # Ensures the LiveView has handled :job_enqueued and subscribed to the job topics.
      assert render(view) =~ "No logs yet."

      assert %{success: 1} = Oban.drain_queue(queue: :default)

      html = flush(view)
      assert html =~ "Backfilling user 42"

      assert view |> element("[data-job-id='#{job_id}'] .oc-badge") |> render() =~ "Completed"
    end
  end

  describe "duplicate executions" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chores")
      select_chore(view, UserBackfill)
      view |> chore_form(UserBackfill, %{user_id: "7"}) |> render_submit()

      {:ok, view: view}
    end

    test "warn before enqueueing the same args again", %{view: view} do
      html = view |> chore_form(UserBackfill, %{user_id: "7"}) |> render_submit()

      assert html =~ "Duplicate Execution Warning"
      assert [_] = all_enqueued(worker: UserBackfill)
    end

    test "can be cancelled", %{view: view} do
      view |> chore_form(UserBackfill, %{user_id: "7"}) |> render_submit()

      html = view |> warning_button(UserBackfill, "cancel_execute") |> render_click()

      refute html =~ "Duplicate Execution Warning"
      assert [_] = all_enqueued(worker: UserBackfill)
    end

    test "are rejected by Oban when unique execution is enabled", %{view: view} do
      view |> chore_form(UserBackfill, %{user_id: "7"}) |> render_submit()
      view |> warning_button(UserBackfill, "confirm_execute") |> render_click()

      html = render(view)
      assert html =~ "Job already running with these arguments"
      refute html =~ "Duplicate Execution Warning"
      assert [_] = all_enqueued(worker: UserBackfill)
    end

    test "are enqueued when unique execution is disabled", %{view: view} do
      view |> element("button[phx-value-tab='new']") |> render_click()
      view |> element(unique_toggle(UserBackfill)) |> render_click()

      view |> chore_form(UserBackfill, %{user_id: "7"}) |> render_submit()
      view |> warning_button(UserBackfill, "confirm_execute") |> render_click()

      assert render(view) =~ "Successfully enqueued User Backfill"
      assert [_, _] = all_enqueued(worker: UserBackfill)
    end
  end

  test "worker-level uniqueness prevents duplicate jobs", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/chores")
    select_chore(view, UniqueCleanup)

    view |> chore_form(UniqueCleanup, %{scope: "all"}) |> render_submit()
    view |> element("button[phx-value-tab='new']") |> render_click()
    view |> chore_form(UniqueCleanup, %{scope: "all"}) |> render_submit()
    view |> warning_button(UniqueCleanup, "confirm_execute") |> render_click()

    assert render(view) =~ "Job already running with these arguments"
    assert [_] = all_enqueued(worker: UniqueCleanup)
  end

  test "updates counts broadcast by the plugin", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/chores")

    Phoenix.PubSub.broadcast(PubSub, "oban_chore:counts", {:oban_chore_count, UniqueCleanup, 3})

    assert view |> element(chore_button(UniqueCleanup) <> " .oc-badge") |> render() =~ "3"
  end

  defp select_chore(view, chore) do
    view |> element(chore_button(chore)) |> render_click()
  end

  defp chore_button(chore), do: "button[phx-value-module='#{chore}']"

  defp visible_chore(chore), do: "[data-chore='#{inspect(chore)}'].oc-block"

  defp chore_form(view, chore, args) do
    form(view, "[data-chore='#{inspect(chore)}'] form", %{args: args})
  end

  defp unique_toggle(chore) do
    "[data-chore='#{inspect(chore)}'] .oc-tooltip-wrapper input[type='checkbox']"
  end

  defp warning_button(view, chore, event) do
    element(view, "[data-chore='#{inspect(chore)}'] button[phx-click='#{event}']")
  end

  defp job_tab(job_id), do: "button[phx-value-tab='job_#{job_id}']"

  # Job status and log messages reach the JobComponent through send_update/3, which the
  # LiveView processes as a separate message, so the first render only drains the mailbox.
  defp flush(view) do
    _ = render(view)
    render(view)
  end
end
