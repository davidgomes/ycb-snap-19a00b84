defmodule GRPC.Client.Adapters.Gun.StreamResponseProcessTest do
  use ExUnit.Case, async: true

  alias GRPC.Client.Adapters.Gun.StreamResponseProcess

  setup do
    {:ok, pid} = StreamResponseProcess.start_link()
    %{pid: pid, monitor_ref: Process.monitor(pid)}
  end

  test "stops after a terminal response is consumed", %{pid: pid, monitor_ref: monitor_ref} do
    send(pid, {:gun_response, self(), make_ref(), :fin, 200, []})

    assert {:response, :fin, 200, []} = StreamResponseProcess.await(pid, 100)
    assert_receive {:DOWN, ^monitor_ref, :process, ^pid, :normal}, 500
  end

  test "returns messages in arrival order until the trailers", %{
    pid: pid,
    monitor_ref: monitor_ref
  } do
    stream_ref = make_ref()
    send(pid, {:gun_response, self(), stream_ref, :nofin, 200, []})
    send(pid, {:gun_data, self(), stream_ref, :nofin, "body"})
    send(pid, {:gun_trailers, self(), stream_ref, [{"grpc-status", "0"}]})

    assert {:response, :nofin, 200, []} = StreamResponseProcess.await(pid, 100)
    assert {:data, :nofin, "body"} = StreamResponseProcess.await(pid, 100)
    assert {:trailers, [{"grpc-status", "0"}]} = StreamResponseProcess.await(pid, 100)
    assert_receive {:DOWN, ^monitor_ref, :process, ^pid, :normal}, 500
  end

  test "replies to a waiting reader as soon as a message arrives", %{pid: pid} do
    task = Task.async(fn -> StreamResponseProcess.await(pid, 1_000) end)
    Process.sleep(50)

    send(pid, {:gun_data, self(), make_ref(), :nofin, "body"})

    assert {:data, :nofin, "body"} = Task.await(task)
  end

  test "returns an error for unexpected messages instead of timing out", %{
    pid: pid,
    monitor_ref: monitor_ref
  } do
    send(pid, :unexpected_message)

    assert {:error, {:unexpected_message, ":unexpected_message"}} =
             StreamResponseProcess.await(pid, 100)

    assert_receive {:DOWN, ^monitor_ref, :process, ^pid, :normal}, 500
  end

  test "keeps queued shutdown errors after non-final headers", %{
    pid: pid,
    monitor_ref: monitor_ref
  } do
    send(pid, {:gun_response, self(), make_ref(), :nofin, 200, []})
    send(pid, {:connection_down, :shutdown})

    assert {:response, :nofin, 200, []} = StreamResponseProcess.await(pid, 100)
    assert {:error, {:connection_error, :shutdown}} = StreamResponseProcess.await(pid, 100)
    assert_receive {:DOWN, ^monitor_ref, :process, ^pid, :normal}, 500
    assert {:error, {:connection_error, :closed}} = StreamResponseProcess.await(pid, 100)
  end

  test "ignores messages that arrive after a terminal message", %{
    pid: pid,
    monitor_ref: monitor_ref
  } do
    send(pid, {:gun_trailers, self(), make_ref(), [{"grpc-status", "0"}]})
    send(pid, {:connection_down, :shutdown})

    assert {:trailers, [{"grpc-status", "0"}]} = StreamResponseProcess.await(pid, 100)
    assert_receive {:DOWN, ^monitor_ref, :process, ^pid, :normal}, 500
  end

  test "stops when a read times out", %{pid: pid, monitor_ref: monitor_ref} do
    assert {:error, :timeout} = StreamResponseProcess.await(pid, 50)
    assert_receive {:DOWN, ^monitor_ref, :process, ^pid, :normal}, 500
  end

  test "stops when cancelled", %{pid: pid, monitor_ref: monitor_ref} do
    :ok = StreamResponseProcess.cancel(pid)
    assert_receive {:DOWN, ^monitor_ref, :process, ^pid, :normal}, 500
  end

  test "stops when its owner exits" do
    owner = spawn(fn -> receive(do: (:stop -> :ok)) end)
    {:ok, pid} = StreamResponseProcess.start_link(owner)
    monitor_ref = Process.monitor(pid)

    send(owner, :stop)

    assert_receive {:DOWN, ^monitor_ref, :process, ^pid, :normal}, 500
  end
end
