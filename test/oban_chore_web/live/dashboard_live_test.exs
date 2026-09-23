defmodule ObanChoreWeb.DashboardLiveTest do
  use ObanChore.DataCase, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias ObanChore.Test.{BackfillChore, UniqueChore}

  @endpoint ObanChoreWeb.TestEndpoint
  @pubsub ObanChore.Test.PubSub

  setup do
    start_supervised!(
      {ObanChore.Plugin, chores: [BackfillChore, UniqueChore], pubsub_server: @pubsub}
    )

    {:ok, conn: build_conn()}
  end

  defp select_chore(view, name) do
    view |> element("button[phx-click=select_chore]", name) |> render_click()
  end

  defp chore_form(view) do
    element(view, ".oc-block form")
  end

  defp insert_job!(worker, args) do
    {:ok, job} = Oban.insert(worker.new(args))
    job
  end

  describe "mount" do
    test "lists the registered chores in the sidebar", %{conn: conn} do
      {:ok, view, html} = live(conn, "/chores")

      assert html =~ "Backfill Chore"
      assert html =~ "Unique Chore"
      assert html =~ "No chore selected"
      assert has_element?(view, "button[phx-value-module='#{BackfillChore}']")
      assert has_element?(view, "button[phx-value-module='#{UniqueChore}']")
    end

    test "shows the number of active jobs per chore", %{conn: conn} do
      insert_job!(BackfillChore, %{user_id: 1})
      insert_job!(BackfillChore, %{user_id: 2})

      {:ok, view, _html} = live(conn, "/chores")

      assert view
             |> element("button[phx-value-module='#{BackfillChore}'] .oc-badge")
             |> render() =~ "2"

      refute has_element?(view, "button[phx-value-module='#{UniqueChore}'] .oc-badge")
    end

    test "shows active jobs as tabs of their chore", %{conn: conn} do
      job = insert_job!(BackfillChore, %{user_id: 7})

      {:ok, view, _html} = live(conn, "/chores")
      html = select_chore(view, "Backfill Chore")

      assert html =~ "Job ##{job.id}"
    end
  end

  describe "selecting a chore" do
    test "renders its description and form fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chores")

      html = select_chore(view, "Backfill Chore")

      assert html =~ "Backfills data for a single user."
      assert has_element?(view, "button[phx-value-module='#{BackfillChore}'].oc-nav-item--active")
      assert has_element?(chore_form(view))
      assert has_element?(view, "input[name='args[user_id]']")
      assert has_element?(view, "textarea[name='args[reason]']")
    end

    test "falls back to a default subtitle without a description", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chores")

      assert select_chore(view, "Unique Chore") =~ "Configure and execute this chore."
    end
  end

  describe "executing a chore" do
    test "shows validation errors on change", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chores")
      select_chore(view, "Backfill Chore")

      html =
        view
        |> chore_form()
        |> render_change(%{"args" => %{"user_id" => "-1"}})

      assert html =~ "must be greater than 0"
    end

    test "does not enqueue a job for invalid args", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chores")
      select_chore(view, "Backfill Chore")

      html =
        view
        |> chore_form()
        |> render_submit(%{"args" => %{"user_id" => ""}})

      assert html =~ "can&#39;t be blank"
      refute_enqueued(worker: BackfillChore)
    end

    test "enqueues a job and opens its tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chores")
      select_chore(view, "Backfill Chore")

      view
      |> chore_form()
      |> render_submit(%{"args" => %{"user_id" => "12", "reason" => "support ticket"}})

      assert_enqueued(worker: BackfillChore, args: %{user_id: 12, reason: "support ticket"})
      [job] = all_enqueued(worker: BackfillChore)

      html = render(view)
      assert html =~ "Successfully enqueued Backfill Chore"
      assert has_element?(view, "button[phx-value-tab='job_#{job.id}'].oc-tab-item--active")
      assert html =~ "support ticket"
    end

    test "warns before enqueuing a duplicate and can be cancelled", %{conn: conn} do
      insert_job!(BackfillChore, %{user_id: 5, reason: nil})

      {:ok, view, _html} = live(conn, "/chores")
      select_chore(view, "Backfill Chore")

      html =
        view
        |> chore_form()
        |> render_submit(%{"args" => %{"user_id" => "5"}})

      assert html =~ "Duplicate Execution Warning"

      view |> element("button", "Cancel") |> render_click()

      refute render(view) =~ "Duplicate Execution Warning"
      assert length(all_enqueued(worker: BackfillChore)) == 1
    end

    test "enqueues a duplicate when confirmed without unique execution", %{conn: conn} do
      insert_job!(BackfillChore, %{user_id: 5, reason: nil})

      {:ok, view, _html} = live(conn, "/chores")
      select_chore(view, "Backfill Chore")

      view |> element("[id='unique-#{BackfillChore}']") |> render_click()

      view
      |> chore_form()
      |> render_submit(%{"args" => %{"user_id" => "5"}})

      view |> element("button", "Confirm anyway") |> render_click()

      assert render(view) =~ "Successfully enqueued Backfill Chore"
      assert length(all_enqueued(worker: BackfillChore)) == 2
    end

    test "reports a conflict when confirmed with unique execution", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chores")
      select_chore(view, "Backfill Chore")

      view |> chore_form() |> render_submit(%{"args" => %{"user_id" => "5"}})
      view |> element("button[phx-value-tab='new']") |> render_click()

      assert view |> chore_form() |> render_submit(%{"args" => %{"user_id" => "5"}}) =~
               "Duplicate Execution Warning"

      view |> element("button", "Confirm anyway") |> render_click()

      assert render(view) =~ "Job already running with these arguments"
      assert length(all_enqueued(worker: BackfillChore)) == 1
    end

    test "disables the unique toggle for workers with unique options", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chores")
      select_chore(view, "Unique Chore")

      assert has_element?(view, "[id='unique-#{UniqueChore}'][disabled]")
      assert render(view) =~ "Uniqueness is enforced by the worker definition."
    end
  end

  describe "real-time updates" do
    test "updates chore counts from broadcasts", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/chores")

      Phoenix.PubSub.broadcast(@pubsub, "oban_chore:counts", {:oban_chore_count, UniqueChore, 3})

      assert view
             |> element("button[phx-value-module='#{UniqueChore}'] .oc-badge")
             |> render() =~ "3"
    end

    test "streams logs and state changes to the job tab", %{conn: conn} do
      job = insert_job!(BackfillChore, %{user_id: 9})

      {:ok, view, _html} = live(conn, "/chores")
      select_chore(view, "Backfill Chore")
      html = view |> element("button[phx-value-tab='job_#{job.id}']") |> render_click()

      assert html =~ "No logs yet."

      Phoenix.PubSub.broadcast(
        @pubsub,
        "oban_chore:status:#{job.id}",
        {:oban_chore_state, job.id, :executing}
      )

      assert render(view) =~ "Waiting for logs..."

      ObanChore.log(job, "Processing user 9")

      html = render(view)
      assert html =~ "Processing user 9"
      assert html =~ "Executing"
    end

    test "selecting the new execution tab hides the job", %{conn: conn} do
      job = insert_job!(BackfillChore, %{user_id: 9})

      {:ok, view, _html} = live(conn, "/chores")
      select_chore(view, "Backfill Chore")
      view |> element("button[phx-value-tab='job_#{job.id}']") |> render_click()
      view |> element("button[phx-value-tab='new']") |> render_click()

      assert has_element?(view, "button[phx-value-tab='new'].oc-tab-item--active")
      refute has_element?(view, "button[phx-value-tab='job_#{job.id}'].oc-tab-item--active")
    end
  end
end
