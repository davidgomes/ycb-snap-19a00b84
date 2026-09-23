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

  test "ignores messages that arrive after the stream finished" do
    {:ok, pid} = StreamResponseProcess.start_link()

    send(pid, {:gun_trailers, self(), make_ref(), [{"grpc-status", "0"}]})
    send(pid, {:gun_error, self(), make_ref(), :closed})

    assert {:trailers, [{"grpc-status", "0"}]} = StreamResponseProcess.await(pid, 100)
    assert {:error, {:connection_error, :closed}} = StreamResponseProcess.await(pid, 100)
  end

  test "times out an await and stops so the stream gets cancelled" do
    Process.flag(:trap_exit, true)
    {:ok, pid} = StreamResponseProcess.start_link()

    assert {:error, :timeout} = StreamResponseProcess.await(pid, 10)
    assert_receive {:EXIT, ^pid, {:shutdown, :timeout}}, 500
  end

  test "stops when its owner exits before the stream finished" do
    Process.flag(:trap_exit, true)
    owner = spawn(fn -> Process.sleep(:infinity) end)
    {:ok, pid} = StreamResponseProcess.start_link(owner: owner)

    Process.exit(owner, :kill)

    assert_receive {:EXIT, ^pid, {:shutdown, :owner_down}}, 500
  end

  test "stops normally when its owner exits after the stream finished" do
    Process.flag(:trap_exit, true)
    owner = spawn(fn -> Process.sleep(:infinity) end)
    {:ok, pid} = StreamResponseProcess.start_link(owner: owner)

    send(pid, {:gun_response, self(), make_ref(), :fin, 200, []})
    Process.exit(owner, :kill)

    assert_receive {:EXIT, ^pid, :normal}, 500
  end

  test "stops on cancel and fails pending awaits" do
    {:ok, pid} = StreamResponseProcess.start_link()
    monitor_ref = Process.monitor(pid)

    task = Task.async(fn -> StreamResponseProcess.await(pid, :infinity) end)
    :ok = StreamResponseProcess.cancel(pid)

    assert {:error, {:connection_error, :closed}} = Task.await(task)
    assert_receive {:DOWN, ^monitor_ref, :process, ^pid, :normal}, 500
  end
end
