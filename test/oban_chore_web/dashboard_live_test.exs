defmodule ObanChoreWeb.DashboardLiveTest do
  use ExUnit.Case, async: false

  alias ObanChoreWeb.DashboardLive
  alias Phoenix.LiveView.Socket

  setup do
    start_supervised!({Phoenix.PubSub, name: ObanChore.TestPubSub})
    Application.put_env(:oban_chore, :pubsub_server, ObanChore.TestPubSub)
    on_exit(fn -> Application.delete_env(:oban_chore, :pubsub_server) end)

    socket = %Socket{
      assigns: %{
        __changed__: %{},
        chores: [],
        counts: %{},
        selected_chore_module: nil,
        jobs: %{},
        chore_jobs: %{},
        selected_tab: :new
      }
    }

    {:ok, socket: socket}
  end

  test "select_chore selects the module and resets the tab", %{socket: socket} do
    socket = Phoenix.Component.assign(socket, selected_tab: {:job, 1})

    {:noreply, socket} =
      DashboardLive.handle_event("select_chore", %{"module" => "Elixir.Enum"}, socket)

    assert socket.assigns.selected_chore_module == Enum
    assert socket.assigns.selected_tab == :new
  end

  test "select_tab switches between the new tab and job tabs", %{socket: socket} do
    {:noreply, socket} = DashboardLive.handle_event("select_tab", %{"tab" => "job_12"}, socket)
    assert socket.assigns.selected_tab == {:job, 12}

    {:noreply, socket} = DashboardLive.handle_event("select_tab", %{"tab" => "new"}, socket)
    assert socket.assigns.selected_tab == :new
  end

  test "count messages update the counts", %{socket: socket} do
    {:noreply, socket} = DashboardLive.handle_info({:oban_chore_count, SomeWorker, 3}, socket)

    assert socket.assigns.counts == %{SomeWorker => 3}
  end

  test "job_enqueued tracks the job and selects its tab", %{socket: socket} do
    job = %Oban.Job{id: 5, state: :available}

    {:noreply, socket} = DashboardLive.handle_info({:job_enqueued, job, SomeWorker}, socket)

    assert socket.assigns.jobs == %{5 => job}
    assert socket.assigns.chore_jobs == %{SomeWorker => [5]}
    assert socket.assigns.selected_tab == {:job, 5}

    other = %Oban.Job{id: 6, state: :available}
    {:noreply, socket} = DashboardLive.handle_info({:job_enqueued, other, SomeWorker}, socket)
    {:noreply, socket} = DashboardLive.handle_info({:job_enqueued, other, SomeWorker}, socket)

    assert socket.assigns.chore_jobs == %{SomeWorker => [6, 5]}
  end

  test "state messages update the tracked job", %{socket: socket} do
    job = %Oban.Job{id: 5, state: :available}
    {:noreply, socket} = DashboardLive.handle_info({:job_enqueued, job, SomeWorker}, socket)

    {:noreply, socket} = DashboardLive.handle_info({:oban_chore_state, 5, :executing}, socket)

    assert socket.assigns.jobs[5].state == :executing
  end
end
