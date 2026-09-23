defmodule ObanChoreWeb.DashboardLiveTest do
  use ObanChore.ConnCase, async: false

  alias ObanChore.TestChores.{UniqueReindex, UserBackfill}

  setup do
    pid =
      start_supervised!(
        {ObanChore.Plugin,
         chores: [UserBackfill, UniqueReindex], pubsub_server: ObanChore.TestPubSub}
      )

    _ = :sys.get_state(pid)
    :ok
  end

  describe "mount" do
    test "lists the registered chores with no chore selected", %{conn: conn} do
      {:ok, view, html} = live(conn, "/chores")

      assert html =~ "User Backfill"
      assert html =~ "Unique Reindex"
      assert html =~ "No chore selected"
      refute has_element?(view, ".oc-badge")
    end

    test "shows the number of active jobs per chore", %{conn: conn} do
      insert_job!(UserBackfill, %{user_id: 1})
      insert_job!(UserBackfill, %{user_id: 2}, "scheduled")
      insert_job!(UserBackfill, %{user_id: 3}, "completed")

      {:ok, view, _html} = live(conn, "/chores")

      assert chore_badge(view, UserBackfill) =~ "2"
      refute has_element?(view, "#{chore_button(UniqueReindex)} .oc-badge")
    end

    test "updates the badge when a count is broadcast", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chores")

      Phoenix.PubSub.broadcast(
        ObanChore.TestPubSub,
        "oban_chore:counts",
        {:oban_chore_count, UserBackfill, 5}
      )

      assert chore_badge(view, UserBackfill) =~ "5"
    end
  end

  describe "selecting a chore" do
    test "renders its description and input fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chores")

      html = select_chore(view, UserBackfill)

      assert html =~ "Backfills historical data for a user."
      refute html =~ "No chore selected"
      assert has_element?(view, ".oc-block input[name='args[user_id]']")
      assert has_element?(view, ".oc-block input[name='args[reason]'][value='manual']")
    end

    test "falls back to a generic subtitle without a description", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chores")

      assert select_chore(view, UniqueReindex) =~ "Configure and execute this chore."
    end

    test "lists tabs for the chore's active jobs", %{conn: conn} do
      job = insert_job!(UserBackfill, %{user_id: 1})
      {:ok, view, _html} = live(conn, "/chores")

      select_chore(view, UserBackfill)

      assert has_element?(view, job_tab(job), "Job ##{job.id}")
    end
  end

  describe "executing a chore" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chores")
      select_chore(view, UserBackfill)
      {:ok, view: view}
    end

    test "validates input on change", %{view: view} do
      html =
        view
        |> form(".oc-block form", args: %{user_id: "not a number"})
        |> render_change()

      assert html =~ "is invalid"
    end

    test "shows errors and enqueues nothing for invalid input", %{view: view} do
      html =
        view
        |> form(".oc-block form", args: %{user_id: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
      refute_enqueued(worker: UserBackfill)
    end

    test "enqueues a job and switches to its tab", %{view: view} do
      view
      |> form(".oc-block form", args: %{user_id: "42"})
      |> render_submit()

      assert_enqueued(worker: UserBackfill, args: %{user_id: 42, reason: "manual"})
      [job] = all_enqueued(worker: UserBackfill)

      html = render(view)
      assert html =~ "Successfully enqueued User Backfill"
      assert has_element?(view, "#{job_tab(job)}.oc-tab-item--active")
      assert html =~ "ID: #{job.id}"
    end

    test "warns before enqueuing a duplicate and can be cancelled", %{view: view} do
      insert_job!(UserBackfill, %{user_id: 42, reason: "manual"})

      html =
        view
        |> form(".oc-block form", args: %{user_id: "42"})
        |> render_submit()

      assert html =~ "Duplicate Execution Warning"

      html =
        view
        |> element(".oc-block button", "Cancel")
        |> render_click()

      refute html =~ "Duplicate Execution Warning"
      assert length(all_enqueued(worker: UserBackfill)) == 1
    end

    test "confirming a duplicate is still blocked by unique execution", %{view: view} do
      insert_job!(UserBackfill, %{user_id: 42, reason: "manual"})

      view
      |> form(".oc-block form", args: %{user_id: "42"})
      |> render_submit()

      view
      |> element(".oc-block button", "Confirm anyway")
      |> render_click()

      assert render(view) =~ "Job already running with these arguments"
      assert length(all_enqueued(worker: UserBackfill)) == 1
    end

    test "confirming a duplicate enqueues it when unique execution is off", %{view: view} do
      insert_job!(UserBackfill, %{user_id: 42, reason: "manual"})

      view
      |> element("input[id='unique-#{UserBackfill}']")
      |> render_click()

      view
      |> form(".oc-block form", args: %{user_id: "42"})
      |> render_submit()

      html =
        view
        |> element(".oc-block button", "Confirm anyway")
        |> render_click()

      refute html =~ "Duplicate Execution Warning"
      assert render(view) =~ "Successfully enqueued User Backfill"
      assert length(all_enqueued(worker: UserBackfill)) == 2
    end
  end

  describe "chores with worker-level uniqueness" do
    test "disable the unique toggle", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chores")
      select_chore(view, UniqueReindex)

      assert has_element?(view, "input[id='unique-#{UniqueReindex}'][disabled]")
      assert render(view) =~ "Uniqueness is enforced by the worker definition."
    end

    test "don't enqueue duplicates even when confirmed", %{conn: conn} do
      insert_job!(UniqueReindex, %{index: "users"})
      {:ok, view, _html} = live(conn, "/chores")
      select_chore(view, UniqueReindex)

      view
      |> form(".oc-block form", args: %{index: "users"})
      |> render_submit()

      view
      |> element(".oc-block button", "Confirm anyway")
      |> render_click()

      assert render(view) =~ "Job already running with these arguments"
      assert length(all_enqueued(worker: UniqueReindex)) == 1
    end
  end

  describe "job tabs" do
    setup %{conn: conn} do
      job = insert_job!(UserBackfill, %{user_id: 7})
      {:ok, view, _html} = live(conn, "/chores")
      select_chore(view, UserBackfill)
      view |> element(job_tab(job)) |> render_click()
      {:ok, view: view, job: job}
    end

    test "show the job's arguments and state", %{view: view, job: job} do
      html = render(view)

      assert html =~ "ID: #{job.id}"
      assert html =~ "user_id"
      assert html =~ "Available"
      assert html =~ "No logs yet."
    end

    test "stream logs and state changes for the job", %{view: view, job: job} do
      assert :ok = execute_job(job)

      html = render_synced(view)
      assert html =~ "Backfilling user 7"
      assert html =~ "Completed"
    end

    test "show a waiting message while the job executes", %{view: view, job: job} do
      Phoenix.PubSub.broadcast(
        ObanChore.TestPubSub,
        "oban_chore:status:#{job.id}",
        {:oban_chore_state, job.id, :executing}
      )

      html = render_synced(view)
      assert html =~ "Executing"
      assert html =~ "Waiting for logs..."
    end

    test "switch back to the new execution form", %{view: view} do
      view |> element("button[phx-value-tab='new']") |> render_click()

      assert has_element?(view, ".oc-block form")
    end
  end

  defp chore_button(module), do: "button[phx-value-module='#{module}']"

  defp job_tab(job), do: "button[phx-value-tab='job_#{job.id}']"

  defp chore_badge(view, module) do
    view |> element("#{chore_button(module)} .oc-badge") |> render()
  end

  defp select_chore(view, module) do
    view |> element(chore_button(module)) |> render_click()
  end

  # Job logs and states reach JobComponent through send_update/3, which the LiveView
  # handles as a separate message after the PubSub broadcast that triggered it.
  defp render_synced(view) do
    _ = :sys.get_state(view.pid)
    render(view)
  end
end
