defmodule GRPC.Client.Adapters.Gun.StreamResponseProcessTest do
  use ExUnit.Case, async: true

  alias GRPC.Client.Adapters.Gun.StreamResponseProcess

  test "stops after a terminal response is consumed" do
    {:ok, pid} = StreamResponseProcess.start_link()
    monitor_ref = Process.monitor(pid)

    send(pid, {:gun_response, self(), make_ref(), :fin, 200, []})

    assert {:response, :fin, 200, []} = StreamResponseProcess.await(pid, 100)
    assert_receive {:DOWN, ^monitor_ref, :process, ^pid, :normal}, 500
  end

  test "returns an error for unexpected messages instead of timing out" do
    {:ok, pid} = StreamResponseProcess.start_link()
    monitor_ref = Process.monitor(pid)

    send(pid, :unexpected_message)

    assert {:error, {:unexpected_message, ":unexpected_message"}} =
             StreamResponseProcess.await(pid, 100)

    assert_receive {:DOWN, ^monitor_ref, :process, ^pid, :normal}, 500
  end

  test "keeps queued shutdown errors after non-final headers" do
    {:ok, pid} = StreamResponseProcess.start_link()
    monitor_ref = Process.monitor(pid)

    send(pid, {:gun_response, self(), make_ref(), :nofin, 200, []})
    send(pid, {:connection_down, :shutdown})

    assert {:response, :nofin, 200, []} = StreamResponseProcess.await(pid, 100)
    assert {:error, {:connection_error, :shutdown}} = StreamResponseProcess.await(pid, 100)
    assert_receive {:DOWN, ^monitor_ref, :process, ^pid, :normal}, 500
    assert {:error, {:connection_error, :closed}} = StreamResponseProcess.await(pid, 100)
  end

  test "a timed out await does not end the stream" do
    {:ok, pid} = StreamResponseProcess.start_link()

    assert {:error, :timeout} = StreamResponseProcess.await(pid, 10)

    send(pid, {:gun_response, self(), make_ref(), :fin, 200, []})
    assert {:response, :fin, 200, []} = StreamResponseProcess.await(pid, 100)
  end

  test "reports the Gun connection going away" do
    gun_pid = spawn(fn -> receive do: (:stop -> :ok) end)
    {:ok, pid} = StreamResponseProcess.start_link(gun_pid: gun_pid)

    send(gun_pid, :stop)

    assert {:error, {:down, :normal}} = StreamResponseProcess.await(pid, 500)
  end

  test "stops when the process that issued the request exits" do
    owner = spawn(fn -> receive do: (:stop -> :ok) end)
    {:ok, pid} = StreamResponseProcess.start_link(owner: owner)
    monitor_ref = Process.monitor(pid)

    send(pid, {:gun_response, self(), make_ref(), :nofin, 200, []})
    send(owner, :stop)

    assert_receive {:DOWN, ^monitor_ref, :process, ^pid, :normal}, 500
  end
end
