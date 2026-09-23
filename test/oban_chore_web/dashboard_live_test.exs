defmodule ObanChoreWeb.DashboardLiveTest do
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias ObanChore.Test.MockRepo
  alias ObanChoreWeb.DashboardLive
  alias Phoenix.LiveView.Socket

  @app :oban_chore_dashboard_test
  @pubsub ObanChoreWeb.DashboardLiveTest.PubSub

  defmodule ReportChore do
    use ObanChore.Worker,
      name: "Monthly Report",
      description: "Builds the monthly report.",
      fields: [month: [type: :string, required: true]]

    @impl Oban.Worker
    def perform(_job), do: :ok
  end

  defmodule CleanupChore do
    use ObanChore.Worker, name: "Cleanup", fields: []

    @impl Oban.Worker
    def perform(_job), do: :ok
  end

  setup do
    :ok = :application.load({:application, @app, [modules: [ReportChore, CleanupChore]]})

    start_supervised!({Phoenix.PubSub, name: @pubsub})

    start_supervised!(
      {Oban, name: Oban, repo: MockRepo, testing: :inline, notifier: Oban.Notifiers.Isolated}
    )

    start_supervised!({ObanChore.Plugin, otp_app: @app, pubsub_server: @pubsub})

    on_exit(fn ->
      :telemetry.detach({:oban_chore_counts, Oban})
      :application.unload(@app)
      Application.delete_env(:oban_chore, :pubsub_server)
    end)

    report_job = %Oban.Job{
      id: 1,
      worker: inspect(ReportChore),
      args: %{"month" => "May"},
      state: "executing"
    }

    stub_by_worker(:all, %{inspect(ReportChore) => [report_job]}, [])
    stub_by_worker(:aggregate, %{inspect(ReportChore) => 1}, 0)

    :ok
  end

  defp stub_by_worker(callback, results, default) do
    MockRepo.stub(callback, fn query ->
      Map.get(results, MockRepo.worker_filter(query), default)
    end)
  end

  defp mount_dashboard(socket \\ %Socket{}) do
    {:ok, socket} = DashboardLive.mount(%{}, %{}, socket)
    socket
  end

  defp connected_socket, do: %Socket{transport_pid: self()}

  defp render_dashboard(socket) do
    assigns = socket.assigns |> Map.delete(:__changed__) |> Map.put(:flash, %{})
    render_component(&DashboardLive.render/1, assigns)
  end

  defp new_job(id) do
    %Oban.Job{id: id, worker: inspect(ReportChore), args: %{"month" => "June"}, state: :available}
  end

  describe "mount/3" do
    test "loads the discovered chores with their counts and active jobs" do
      socket = mount_dashboard()

      assert socket.assigns.chores == [
               ReportChore.__chore_info__(),
               CleanupChore.__chore_info__()
             ]

      assert socket.assigns.counts == %{ReportChore => 1, CleanupChore => 0}
      assert %{1 => %Oban.Job{id: 1, state: :executing}} = socket.assigns.jobs
      assert socket.assigns.chore_jobs == %{ReportChore => [1], CleanupChore => []}
      assert socket.assigns.selected_chore_module == nil
      assert socket.assigns.selected_tab == :new
    end

    test "subscribes to counts and active job updates once connected" do
      mount_dashboard(connected_socket())

      Phoenix.PubSub.broadcast(@pubsub, "oban_chore:counts", {:oban_chore_count, ReportChore, 2})
      Phoenix.PubSub.broadcast(@pubsub, "oban_chore:status:1", {:oban_chore_state, 1, :completed})
      Phoenix.PubSub.broadcast(@pubsub, "oban_chore:logs:1", {:oban_chore_log, 1, "Working..."})

      assert_receive {:oban_chore_count, ReportChore, 2}
      assert_receive {:oban_chore_state, 1, :completed}
      assert_receive {:oban_chore_log, 1, "Working..."}
    end

    test "does not subscribe before the socket is connected" do
      mount_dashboard()

      Phoenix.PubSub.broadcast(@pubsub, "oban_chore:counts", {:oban_chore_count, ReportChore, 2})
      Phoenix.PubSub.broadcast(@pubsub, "oban_chore:status:1", {:oban_chore_state, 1, :completed})

      refute_receive {:oban_chore_count, _, _}
      refute_receive {:oban_chore_state, _, _}
    end
  end

  describe "handle_event/3" do
    test "select_chore selects the chore and resets the tab" do
      socket = mount_dashboard()
      socket = put_in(socket.assigns.selected_tab, {:job, 1})

      {:noreply, socket} =
        DashboardLive.handle_event("select_chore", %{"module" => to_string(ReportChore)}, socket)

      assert socket.assigns.selected_chore_module == ReportChore
      assert socket.assigns.selected_tab == :new
    end

    test "select_tab switches between the new execution form and job tabs" do
      socket = mount_dashboard()

      {:noreply, socket} = DashboardLive.handle_event("select_tab", %{"tab" => "job_1"}, socket)
      assert socket.assigns.selected_tab == {:job, 1}

      {:noreply, socket} = DashboardLive.handle_event("select_tab", %{"tab" => "new"}, socket)
      assert socket.assigns.selected_tab == :new
    end
  end

  describe "handle_info/2" do
    test "updates the running count of a chore" do
      socket = mount_dashboard()

      {:noreply, socket} = DashboardLive.handle_info({:oban_chore_count, CleanupChore, 4}, socket)

      assert socket.assigns.counts == %{ReportChore => 1, CleanupChore => 4}
    end

    test "tracks a newly enqueued job and opens its tab" do
      socket = mount_dashboard(connected_socket())

      {:noreply, socket} =
        DashboardLive.handle_info({:job_enqueued, new_job(2), ReportChore}, socket)

      assert socket.assigns.jobs[2] == new_job(2)
      assert socket.assigns.chore_jobs[ReportChore] == [2, 1]
      assert socket.assigns.selected_tab == {:job, 2}

      Phoenix.PubSub.broadcast(@pubsub, "oban_chore:status:2", {:oban_chore_state, 2, :executing})
      Phoenix.PubSub.broadcast(@pubsub, "oban_chore:logs:2", {:oban_chore_log, 2, "Started"})

      assert_receive {:oban_chore_state, 2, :executing}
      assert_receive {:oban_chore_log, 2, "Started"}
    end

    test "does not track the same job twice" do
      socket = mount_dashboard()

      {:noreply, socket} =
        DashboardLive.handle_info({:job_enqueued, new_job(2), ReportChore}, socket)

      {:noreply, socket} =
        DashboardLive.handle_info({:job_enqueued, new_job(2), ReportChore}, socket)

      assert socket.assigns.chore_jobs[ReportChore] == [2, 1]
    end

    test "tracks jobs for chores that had no active jobs" do
      socket = mount_dashboard()
      job = %{new_job(3) | worker: inspect(CleanupChore)}

      {:noreply, socket} = DashboardLive.handle_info({:job_enqueued, job, CleanupChore}, socket)

      assert socket.assigns.chore_jobs[CleanupChore] == [3]
    end

    test "updates the job state and forwards it to the job component" do
      socket = mount_dashboard()

      {:noreply, socket} = DashboardLive.handle_info({:oban_chore_state, 1, :completed}, socket)

      assert socket.assigns.jobs[1].state == :completed

      assert_received {:phoenix, :send_update,
                       {{ObanChoreWeb.JobComponent, 1}, %{id: 1, new_state: :completed}}}
    end

    test "forwards log lines to the job component" do
      socket = mount_dashboard()

      {:noreply, _socket} = DashboardLive.handle_info({:oban_chore_log, 1, "Working..."}, socket)

      assert_received {:phoenix, :send_update,
                       {{ObanChoreWeb.JobComponent, 1}, %{id: 1, new_log: "Working..."}}}
    end
  end

  describe "render/1" do
    test "lists the chores with their counts and prompts for a selection" do
      html = mount_dashboard() |> render_dashboard()

      assert html =~ "Monthly Report"
      assert html =~ "Cleanup"
      assert html =~ ~s(phx-value-module="Elixir.ObanChoreWeb.DashboardLiveTest.ReportChore")
      assert [_only_report_chore] = Regex.scan(~r/oc-badge-blue[^>]*>\s*1\s*</, html)
      assert html =~ "No chore selected"
    end

    test "shows the selected chore with its form and active jobs" do
      socket = mount_dashboard()

      {:noreply, socket} =
        DashboardLive.handle_event("select_chore", %{"module" => to_string(ReportChore)}, socket)

      html = render_dashboard(socket)

      refute html =~ "No chore selected"
      assert html =~ ~s(<h2 class="oc-title">)
      assert html =~ "Builds the monthly report."
      assert html =~ "New Execution"
      assert html =~ "Job #1"
      assert html =~ "oc-status-dot--pulse"
      assert html =~ ~s(name="args[month]")
      assert html =~ "&quot;May&quot;"
    end

    test "falls back to a default subtitle for chores without a description" do
      socket = mount_dashboard()

      {:noreply, socket} =
        DashboardLive.handle_event("select_chore", %{"module" => to_string(CleanupChore)}, socket)

      html = render_dashboard(socket)

      assert html =~ "Configure and execute this chore."
      refute html =~ "Job #1"
    end
  end
end
