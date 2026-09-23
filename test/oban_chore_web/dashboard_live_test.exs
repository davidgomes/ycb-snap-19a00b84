defmodule ObanChoreWeb.DashboardLiveTest do
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias ObanChore.Test.MockRepo
  alias ObanChoreWeb.DashboardLive
  alias Phoenix.LiveView.Socket

  @app :oban_chore_dashboard_test_app
  @pubsub ObanChoreWeb.DashboardLiveTest.PubSub

  defmodule BackfillChore do
    use ObanChore.Worker,
      name: "User Backfill",
      description: "Backfills user data.",
      fields: [user_id: [type: :integer, required: true]]

    @impl Oban.Worker
    def perform(_job), do: :ok
  end

  defmodule CleanupChore do
    use ObanChore.Worker, name: "Cleanup", fields: []

    @impl Oban.Worker
    def perform(_job), do: :ok
  end

  setup do
    spec = [
      description: ~c"ObanChore test app",
      vsn: ~c"0.0.0",
      modules: [BackfillChore, CleanupChore]
    ]

    :ok = :application.load({:application, @app, spec})

    on_exit(fn ->
      :telemetry.detach({:oban_chore_counts, Oban})
      Application.delete_env(:oban_chore, :pubsub_server)
      :application.unload(@app)
    end)

    start_supervised!({Phoenix.PubSub, name: @pubsub})
    start_supervised!({ObanChore.Plugin, otp_app: @app, pubsub_server: @pubsub})
    start_supervised!({Oban, repo: MockRepo, testing: :manual, notifier: Oban.Notifiers.Isolated})

    MockRepo.stub(:aggregate, &for_backfill(&1, 1, 0))
    MockRepo.stub(:all, &for_backfill(&1, [active_job()], []))

    :ok
  end

  defp for_backfill(query, backfill_result, other_result) do
    if inspect(query) =~ ~s(j0.worker == ^"ObanChoreWeb.DashboardLiveTest.BackfillChore"),
      do: backfill_result,
      else: other_result
  end

  defp active_job do
    %Oban.Job{
      id: 1,
      worker: "ObanChoreWeb.DashboardLiveTest.BackfillChore",
      args: %{"user_id" => 7},
      state: "executing"
    }
  end

  defp mount(socket \\ %Socket{}) do
    {:ok, socket} = DashboardLive.mount(%{}, %{}, socket)
    socket
  end

  defp render_dashboard(socket) do
    render_component(&DashboardLive.render/1, Map.put(socket.assigns, :flash, %{}))
  end

  describe "mount/3" do
    test "loads the discovered chores with their counts and active jobs" do
      socket = mount()

      assert socket.assigns.chores == [
               BackfillChore.__chore_info__(),
               CleanupChore.__chore_info__()
             ]

      assert socket.assigns.counts == %{BackfillChore => 1, CleanupChore => 0}
      assert %{1 => %Oban.Job{id: 1, state: :executing}} = socket.assigns.jobs
      assert socket.assigns.chore_jobs == %{BackfillChore => [1], CleanupChore => []}
      assert socket.assigns.selected_chore_module == nil
      assert socket.assigns.selected_tab == :new
    end

    test "subscribes to counts and to the active jobs' logs and status once connected" do
      mount(%Socket{transport_pid: self()})

      Phoenix.PubSub.broadcast(@pubsub, "oban_chore:counts", :count_update)
      Phoenix.PubSub.broadcast(@pubsub, "oban_chore:logs:1", :log_update)
      Phoenix.PubSub.broadcast(@pubsub, "oban_chore:status:1", :status_update)

      assert_receive :count_update
      assert_receive :log_update
      assert_receive :status_update
    end

    test "doesn't subscribe before the socket is connected" do
      mount()

      Phoenix.PubSub.broadcast(@pubsub, "oban_chore:counts", :count_update)
      Phoenix.PubSub.broadcast(@pubsub, "oban_chore:logs:1", :log_update)

      refute_receive :count_update
      refute_receive :log_update
    end
  end

  describe "handle_event/3" do
    test "select_chore selects the chore and opens its new execution tab" do
      socket = Phoenix.Component.assign(mount(), selected_tab: {:job, 1})

      {:noreply, socket} =
        DashboardLive.handle_event(
          "select_chore",
          %{"module" => to_string(BackfillChore)},
          socket
        )

      assert socket.assigns.selected_chore_module == BackfillChore
      assert socket.assigns.selected_tab == :new
    end

    test "select_tab switches between the new execution and job tabs" do
      {:noreply, socket} = DashboardLive.handle_event("select_tab", %{"tab" => "job_1"}, mount())
      assert socket.assigns.selected_tab == {:job, 1}

      {:noreply, socket} = DashboardLive.handle_event("select_tab", %{"tab" => "new"}, socket)
      assert socket.assigns.selected_tab == :new
    end
  end

  describe "handle_info/2" do
    test "updates a chore's count" do
      {:noreply, socket} =
        DashboardLive.handle_info({:oban_chore_count, CleanupChore, 4}, mount())

      assert socket.assigns.counts == %{BackfillChore => 1, CleanupChore => 4}
    end

    test "tracks an enqueued job and opens its tab" do
      job = %Oban.Job{
        id: 2,
        worker: "ObanChoreWeb.DashboardLiveTest.BackfillChore",
        state: :available
      }

      {:noreply, socket} = DashboardLive.handle_info({:job_enqueued, job, BackfillChore}, mount())

      assert socket.assigns.jobs[2] == job
      assert socket.assigns.chore_jobs[BackfillChore] == [2, 1]
      assert socket.assigns.selected_tab == {:job, 2}
    end

    test "doesn't track the same job twice" do
      job = %{active_job() | state: :executing}

      {:noreply, socket} = DashboardLive.handle_info({:job_enqueued, job, BackfillChore}, mount())

      assert socket.assigns.chore_jobs[BackfillChore] == [1]
    end

    test "subscribes to an enqueued job's logs and status once connected" do
      job = %Oban.Job{
        id: 3,
        worker: "ObanChoreWeb.DashboardLiveTest.CleanupChore",
        state: :available
      }

      socket = mount(%Socket{transport_pid: self()})

      {:noreply, _socket} = DashboardLive.handle_info({:job_enqueued, job, CleanupChore}, socket)

      Phoenix.PubSub.broadcast(@pubsub, "oban_chore:logs:3", :log_update)
      Phoenix.PubSub.broadcast(@pubsub, "oban_chore:status:3", :status_update)

      assert_receive :log_update
      assert_receive :status_update
    end

    test "updates a job's state and forwards it to its component" do
      {:noreply, socket} = DashboardLive.handle_info({:oban_chore_state, 1, :completed}, mount())

      assert socket.assigns.jobs[1].state == :completed

      assert_received {:phoenix, :send_update,
                       {{ObanChoreWeb.JobComponent, 1}, %{id: 1, new_state: :completed}}}
    end

    test "forwards log lines to the job's component" do
      socket = mount()

      assert {:noreply, ^socket} =
               DashboardLive.handle_info({:oban_chore_log, 1, "Working..."}, socket)

      assert_received {:phoenix, :send_update,
                       {{ObanChoreWeb.JobComponent, 1}, %{id: 1, new_log: "Working..."}}}
    end
  end

  describe "render/1" do
    test "lists the chores in the sidebar with their active job counts" do
      html = render_dashboard(mount())

      assert html =~ "User Backfill"
      assert html =~ ~s(phx-value-module="Elixir.ObanChoreWeb.DashboardLiveTest.BackfillChore")
      assert html =~ "Cleanup"
      assert html =~ ~s(phx-value-module="Elixir.ObanChoreWeb.DashboardLiveTest.CleanupChore")
      assert html =~ ~r{<span class="oc-badge oc-badge-blue[^"]*">\s*1\s*</span>}
      assert length(Regex.scan(~r/oc-badge-blue/, html)) == 1
    end

    test "asks to pick a chore until one is selected" do
      html = render_dashboard(mount())

      assert html =~ "No chore selected"
      assert html =~ "Select a chore from the sidebar to get started."
      refute html =~ "oc-nav-item--active"
    end
  end
end
