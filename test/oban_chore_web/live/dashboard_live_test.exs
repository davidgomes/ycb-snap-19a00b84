defmodule ObanChoreWeb.DashboardLiveTest do
  use ExUnit.Case, async: false
  use Oban.Testing, repo: ObanChore.TestRepo

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Ecto.Adapters.SQL.Sandbox
  alias ObanChore.TestRepo

  @endpoint ObanChore.TestEndpoint
  @pubsub ObanChore.DashboardPubSub

  defmodule BackfillChore do
    use ObanChore.Worker,
      name: "Backfill Chore",
      description: "Backfills data for a user.",
      queue: :default,
      fields: [
        user_id: [type: :integer, required: true, label: "User ID"],
        reason: [type: :string, default: "Manual"]
      ]

    @impl Oban.Worker
    def perform(_job), do: :ok
  end

  defmodule CleanupChore do
    use ObanChore.Worker,
      name: "Cleanup Chore",
      queue: :default,
      unique: [period: 60],
      fields: []

    @impl Oban.Worker
    def perform(_job), do: :ok
  end

  setup do
    owner = Sandbox.start_owner!(TestRepo, shared: true)
    on_exit(fn -> Sandbox.stop_owner(owner) end)

    start_supervised!({Phoenix.PubSub, name: @pubsub})

    start_supervised!(
      {ObanChore.Plugin, pubsub_server: @pubsub, chores: [BackfillChore, CleanupChore]}
    )

    {:ok, conn: build_conn()}
  end

  test "lists the registered chores with an empty state", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/chores")

    assert html =~ "Backfill Chore"
    assert html =~ "Cleanup Chore"
    assert html =~ "No chore selected"
  end

  test "selecting a chore shows its details and form", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/chores")

    html = select_chore(view, BackfillChore)
    assert html =~ "Backfills data for a user."
    assert html =~ "User ID"
    assert html =~ ~s(value="Manual")
    refute html =~ "No chore selected"

    html = select_chore(view, CleanupChore)
    assert html =~ "Configure and execute this chore."
    assert html =~ "Uniqueness is enforced by the worker definition."
  end

  test "validates the form on change", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/chores")
    select_chore(view, BackfillChore)

    html = view |> chore_form() |> render_change(args: %{user_id: "", reason: "Manual"})
    assert html =~ "can&#39;t be blank"

    html = view |> chore_form() |> render_change(args: %{user_id: "abc", reason: "Manual"})
    assert html =~ "is invalid"
  end

  test "does not enqueue a job when the form is invalid", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/chores")
    select_chore(view, BackfillChore)

    html = view |> chore_form() |> render_submit(args: %{user_id: "", reason: "Manual"})

    assert html =~ "can&#39;t be blank"
    refute_enqueued(worker: BackfillChore)
  end

  test "executing a chore enqueues a job and opens its tab", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/chores")
    select_chore(view, BackfillChore)

    view |> chore_form() |> render_submit(args: %{user_id: "42", reason: "Support ticket"})

    assert_enqueued(worker: BackfillChore, args: %{user_id: 42, reason: "Support ticket"})
    [job] = all_enqueued(worker: BackfillChore)

    html = render(view)
    assert html =~ "Successfully enqueued Backfill Chore"
    assert html =~ "Job ##{job.id}"
    assert html =~ "ID: #{job.id}"
    assert html =~ "Support ticket"
  end

  describe "duplicate executions" do
    setup %{conn: conn} do
      Oban.insert!(BackfillChore.new(%{user_id: 7, reason: "Manual"}))

      {:ok, view, _html} = live(conn, "/chores")
      select_chore(view, BackfillChore)

      html = view |> chore_form() |> render_submit(args: %{user_id: "7", reason: "Manual"})
      assert html =~ "Duplicate Execution Warning"

      {:ok, view: view}
    end

    test "can be cancelled", %{view: view} do
      html = view |> element("button", "Cancel") |> render_click()

      refute html =~ "Duplicate Execution Warning"
      assert [_existing] = all_enqueued(worker: BackfillChore)
    end

    test "are deduplicated by Oban when unique execution is enabled", %{view: view} do
      view |> element("button", "Confirm anyway") |> render_click()

      html = render(view)
      refute html =~ "Duplicate Execution Warning"
      assert html =~ "Job already running with these arguments"
      assert [_existing] = all_enqueued(worker: BackfillChore)
    end

    test "enqueue a new job when unique execution is disabled", %{view: view} do
      view
      |> element(~s(input[id="unique-#{BackfillChore}"]))
      |> render_click()

      view |> element("button", "Confirm anyway") |> render_click()

      assert render(view) =~ "Successfully enqueued Backfill Chore"
      assert [_, _] = all_enqueued(worker: BackfillChore)
    end
  end

  test "shows active jobs and badge counts on mount", %{conn: conn} do
    %{id: job_id} = Oban.insert!(BackfillChore.new(%{user_id: 1, reason: "Manual"}))

    {:ok, view, html} = live(conn, "/chores")
    assert html =~ ~r/oc-badge-blue[^>]*>\s*1\s*</

    html = select_chore(view, BackfillChore)
    assert html =~ "Job ##{job_id}"
  end

  test "reacts to count, status and log broadcasts", %{conn: conn} do
    %{id: job_id} = Oban.insert!(BackfillChore.new(%{user_id: 1, reason: "Manual"}))

    {:ok, view, _html} = live(conn, "/chores")
    select_chore(view, BackfillChore)

    html = view |> element(~s(button[phx-value-tab="job_#{job_id}"])) |> render_click()
    assert html =~ "Available"
    assert html =~ "No logs yet."

    Phoenix.PubSub.broadcast(@pubsub, "oban_chore:counts", {:oban_chore_count, BackfillChore, 5})

    Phoenix.PubSub.broadcast(
      @pubsub,
      "oban_chore:status:#{job_id}",
      {:oban_chore_state, job_id, :executing}
    )

    html = render(view)
    assert html =~ ~r/oc-badge-blue[^>]*>\s*5\s*</
    assert html =~ "Executing"
    assert html =~ "Waiting for logs..."

    ObanChore.log(%Oban.Job{id: job_id}, "Halfway there")

    assert render(view) =~ "Halfway there"
  end

  defp select_chore(view, module) do
    view
    |> element(~s(button[phx-value-module="#{module}"]))
    |> render_click()
  end

  defp chore_form(view), do: form(view, ".oc-block form")
end
