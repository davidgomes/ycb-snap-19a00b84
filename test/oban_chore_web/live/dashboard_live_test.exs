defmodule ObanChoreWeb.DashboardLiveTest do
  use ExUnit.Case, async: false
  use Oban.Testing, repo: ObanChore.TestRepo

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Ecto.Adapters.SQL.Sandbox
  alias ObanChore.TestChores.{AccountCleanup, UserBackfill}

  @endpoint ObanChore.TestEndpoint
  @pubsub ObanChore.TestPubSub

  setup do
    owner = Sandbox.start_owner!(ObanChore.TestRepo, shared: true)
    on_exit(fn -> Sandbox.stop_owner(owner) end)

    start_supervised!({Phoenix.PubSub, name: @pubsub})

    start_supervised!(
      {ObanChore.Plugin, chores: [UserBackfill, AccountCleanup], pubsub_server: @pubsub}
    )

    {:ok, conn: build_conn()}
  end

  test "lists the registered chores until one is selected", %{conn: conn} do
    {:ok, view, html} = live(conn, "/chores")

    assert html =~ "No chore selected"
    assert has_element?(view, nav(UserBackfill), "User Backfill")
    assert has_element?(view, nav(AccountCleanup), "Account Cleanup")
  end

  test "shows the number of active jobs per chore", %{conn: conn} do
    insert_job!(UserBackfill, %{user_id: 1})
    insert_job!(UserBackfill, %{user_id: 2})
    :ok = Oban.cancel_job(insert_job!(UserBackfill, %{user_id: 3}))

    {:ok, view, _html} = live(conn, "/chores")

    assert has_element?(view, "#{nav(UserBackfill)} .oc-badge", "2")
    refute has_element?(view, "#{nav(AccountCleanup)} .oc-badge")
  end

  test "selecting a chore shows its form with default values", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/chores")
    select_chore(view, UserBackfill)

    assert has_element?(view, "#{nav(UserBackfill)}.oc-nav-item--active")
    assert has_element?(view, ".oc-title", "User Backfill")
    assert has_element?(view, ".oc-subtitle", "Backfills data for a single user.")
    assert has_element?(view, "#{panel(UserBackfill)}.oc-block input[name='args[user_id]']")
    assert has_element?(view, "#{panel(UserBackfill)} input[value='Manual update']")
    assert has_element?(view, "#{panel(AccountCleanup)}.oc-hidden")
  end

  test "validates the form as it changes", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/chores")
    select_chore(view, UserBackfill)

    view |> chore_form(UserBackfill, user_id: "abc") |> render_change()
    assert has_element?(view, panel(UserBackfill), "is invalid")

    view |> chore_form(UserBackfill, user_id: "0") |> render_change()
    assert has_element?(view, panel(UserBackfill), "must be greater than 0")
  end

  test "does not enqueue a job for an invalid form", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/chores")
    select_chore(view, UserBackfill)

    view |> chore_form(UserBackfill, user_id: "") |> render_submit()

    assert has_element?(view, panel(UserBackfill), "can't be blank")
    assert all_enqueued(worker: UserBackfill) == []
  end

  test "enqueues a job and switches to its tab", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/chores")
    select_chore(view, UserBackfill)

    view |> chore_form(UserBackfill, user_id: "42") |> render_submit()

    assert [job] = all_enqueued(worker: UserBackfill)
    assert job.args == %{"user_id" => 42, "reason" => "Manual update"}
    assert render(view) =~ "Successfully enqueued User Backfill"
    assert has_element?(view, "#{job_tab(job)}.oc-tab-item--active")
    assert has_element?(view, "#{job_panel(job)}.oc-block", "Available")
    assert has_element?(view, "#{panel(UserBackfill)}.oc-hidden")
  end

  test "disables the unique toggle when the worker defines uniqueness", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/chores")
    select_chore(view, AccountCleanup)

    assert has_element?(view, ".oc-subtitle", "Configure and execute this chore.")
    assert has_element?(view, "#{panel(AccountCleanup)} input[type='checkbox'][disabled]")

    assert has_element?(
             view,
             panel(AccountCleanup),
             "Uniqueness is enforced by the worker definition."
           )

    assert has_element?(view, "#{panel(UserBackfill)} input[type='checkbox'][checked]")
    refute has_element?(view, "#{panel(UserBackfill)} input[type='checkbox'][disabled]")
  end

  describe "submitting args that are already running" do
    setup %{conn: conn} do
      job = insert_job!(UserBackfill, %{user_id: 7, reason: "Manual update"})

      {:ok, view, _html} = live(conn, "/chores")
      select_chore(view, UserBackfill)
      view |> chore_form(UserBackfill, user_id: "7") |> render_submit()

      {:ok, view: view, job: job}
    end

    test "warns before enqueueing", %{view: view} do
      assert has_element?(view, warning(), "Duplicate Execution Warning")
      assert [_job] = all_enqueued(worker: UserBackfill)
    end

    test "cancelling dismisses the warning", %{view: view} do
      view |> element("#{warning()} button", "Cancel") |> render_click()

      refute has_element?(view, warning())
      assert [_job] = all_enqueued(worker: UserBackfill)
    end

    test "confirming keeps a single job while unique execution is on", %{view: view, job: job} do
      view |> element("#{warning()} button", "Confirm anyway") |> render_click()

      refute has_element?(view, warning())
      assert render(view) =~ "Job already running with these arguments"
      assert [%{id: id}] = all_enqueued(worker: UserBackfill)
      assert id == job.id
    end

    test "confirming enqueues another job once unique execution is off", %{view: view} do
      view |> element("#{panel(UserBackfill)} input[type='checkbox']") |> render_click()
      refute has_element?(view, "#{panel(UserBackfill)} input[type='checkbox'][checked]")

      view |> element("#{warning()} button", "Confirm anyway") |> render_click()

      assert render(view) =~ "Successfully enqueued User Backfill"
      assert [_, _] = all_enqueued(worker: UserBackfill)
    end
  end

  describe "active jobs" do
    setup %{conn: conn} do
      job = insert_job!(UserBackfill, %{user_id: 3})

      {:ok, view, _html} = live(conn, "/chores")
      select_chore(view, UserBackfill)
      view |> element(job_tab(job)) |> render_click()

      {:ok, view: view, job: job}
    end

    test "are listed as tabs showing their arguments", %{view: view, job: job} do
      assert has_element?(view, "#{job_panel(job)}.oc-block .oc-job-arg-title", "user_id")
      assert has_element?(view, "#{job_panel(job)} .oc-job-arg-value", "3")
      assert has_element?(view, job_panel(job), "No logs yet.")
      assert has_element?(view, "#{panel(UserBackfill)}.oc-hidden")

      view |> element("button[phx-value-tab='new']") |> render_click()

      assert has_element?(view, "#{panel(UserBackfill)}.oc-block")
      assert has_element?(view, "#{job_panel(job)}.oc-hidden")
    end

    test "stream state changes and logs", %{view: view, job: job} do
      emit_telemetry([:oban, :job, :start], job)
      flush_component_updates(view)

      assert has_element?(view, "#{job_tab(job)}[data-state='executing']")

      assert has_element?(
               view,
               "#{job_panel(job)}[data-state='executing']",
               "Waiting for logs..."
             )

      ObanChore.log(job, "Backfilling user 3")
      flush_component_updates(view)

      assert has_element?(view, "#{job_panel(job)} .oc-log-content", "Backfilling user 3")

      emit_telemetry([:oban, :job, :stop], job)
      flush_component_updates(view)

      assert has_element?(view, "#{job_tab(job)}[data-state='completed']")
      assert has_element?(view, "#{job_panel(job)}[data-state='completed']", "Completed")
    end
  end

  test "updates a chore's badge when its active count changes", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/chores")
    refute has_element?(view, "#{nav(UserBackfill)} .oc-badge")

    job = insert_job!(UserBackfill, %{user_id: 1})
    insert_job!(UserBackfill, %{user_id: 2})
    emit_telemetry([:oban, :job, :start], job)

    assert has_element?(view, "#{nav(UserBackfill)} .oc-badge", "2")
  end

  defp insert_job!(worker, args), do: args |> worker.new() |> Oban.insert!()

  defp emit_telemetry(event, job) do
    :telemetry.execute(event, %{}, %{conf: Oban.config(), job: job})
  end

  # The dashboard forwards job updates to its components with send_update/3, which queues one
  # more message behind the broadcast, so assertions need an extra round trip to see them.
  defp flush_component_updates(view), do: render(view)

  defp select_chore(view, module), do: view |> element(nav(module)) |> render_click()

  defp chore_form(view, module, args), do: form(view, "#{panel(module)} form", args: args)

  defp nav(module), do: "[data-chore-nav='#{inspect(module)}']"
  defp panel(module), do: "[data-chore-panel='#{inspect(module)}']"
  defp warning, do: "#{panel(UserBackfill)} .oc-alert-warning"
  defp job_tab(job), do: "[data-job-tab='#{job.id}']"
  defp job_panel(job), do: "[data-job-panel='#{job.id}']"
end
