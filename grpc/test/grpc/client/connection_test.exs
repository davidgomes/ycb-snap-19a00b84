defmodule GRPC.Client.ConnectionTest do
  use GRPC.Client.DataCase, async: false

  alias GRPC.Channel
  alias GRPC.Client.Connection

  @peer if Code.ensure_loaded?(:peer), do: :peer, else: GRPC.Test.PeerShim

  setup do
    %{
      ref: make_ref(),
      ip: "127.0.0.1",
      target: "ipv4:127.0.0.1:50051",
      adapter: GRPC.Test.ClientAdapter
    }
  end

  describe "pick_channel/2" do
    test "returns {:error, :no_connection} when no persistent_term entry exists", %{ref: ref} do
      channel = %Channel{ref: ref}

      assert {:error, :no_connection} = Connection.pick_channel(channel)
    end

    test "returns {:ok, channel} once the connection has published its LB state", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)

      assert {GRPC.Client.LoadBalancing.PickFirst, %{tid: _}} =
               :persistent_term.get({Connection, ref})

      assert {:ok, ^channel} = Connection.pick_channel(%Channel{ref: ref})

      Connection.disconnect(channel)
    end
  end

  describe "connect/2 - already_started branch" do
    test "returns {:ok, channel} when the GenServer for the same ref is already running", %{
      ref: ref,
      ip: ip,
      target: target,
      adapter: adapter
    } do
      {:ok, first_channel} = Connection.connect(target, adapter: adapter, name: ref)

      # Connecting again with the same ref triggers the :already_started path
      {:ok, second_channel} = Connection.connect(target, adapter: adapter, name: ref)

      assert first_channel.ref == second_channel.ref
      assert second_channel.host == ip
      assert second_channel.port == 50051

      Connection.disconnect(first_channel)
    end

    test "returns {:error, :no_connection} when the running connection has no published LB state",
         %{ref: ref, target: target, adapter: adapter} do
      {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)

      entry = :persistent_term.get({Connection, ref})
      :persistent_term.erase({Connection, ref})

      assert {:error, :no_connection} = Connection.connect(target, adapter: adapter, name: ref)

      :persistent_term.put({Connection, ref}, entry)
      Connection.disconnect(channel)
    end
  end

  describe "disconnect/1" do
    test "GenServer process is no longer alive after disconnect", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)

      pid = whereis_name(ref)

      {:ok, _} = Connection.disconnect(channel)

      ref_mon = Process.monitor(pid)
      assert_receive {:DOWN, ^ref_mon, :process, ^pid, _reason}, 500
    end

    test "pick_channel returns {:error, :no_connection} after disconnect (persistent_term is erased)",
         %{ref: ref, target: target, adapter: adapter} do
      {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)

      {:ok, _} = Connection.disconnect(channel)

      assert {:error, :no_connection} = Connection.pick_channel(channel)
    end
  end

  describe "terminate/2 - persistent_term cleanup on process kill" do
    test "persistent_term is erased when process is killed without disconnect", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)

      pid = whereis_name(ref)
      ref_mon = Process.monitor(pid)
      GenServer.stop(pid, :shutdown)
      assert_receive {:DOWN, ^ref_mon, :process, ^pid, :shutdown}, 500

      assert {:error, :no_connection} = Connection.pick_channel(channel)
    end
  end

  describe "LB ETS table lifecycle" do
    test "the table is owned by the connection process and outlives the caller", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      parent = self()

      {caller, caller_mon} =
        spawn_monitor(fn ->
          opts = [adapter: adapter, name: ref, lb_policy: :round_robin]
          send(parent, {:connected, Connection.connect(target, opts)})
        end)

      assert_receive {:connected, {:ok, channel}}
      assert_receive {:DOWN, ^caller_mon, :process, ^caller, :normal}

      assert :ets.info(lb_tid(ref), :owner) == whereis_name(ref)
      assert {:ok, %Channel{host: "127.0.0.1"}} = Connection.pick_channel(channel)

      Connection.disconnect(channel)
    end

    test "disconnect/1 frees the table", %{ref: ref, target: target, adapter: adapter} do
      {:ok, channel} =
        Connection.connect(target, adapter: adapter, name: ref, lb_policy: :round_robin)

      tid = lb_tid(ref)
      pid = whereis_name(ref)
      ref_mon = Process.monitor(pid)

      {:ok, _} = Connection.disconnect(channel)
      assert_receive {:DOWN, ^ref_mon, :process, ^pid, _reason}, 500

      assert :ets.info(tid) == :undefined
    end

    test "the table is freed when the process is stopped without disconnect", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      {:ok, _channel} = Connection.connect(target, adapter: adapter, name: ref)

      tid = lb_tid(ref)
      pid = whereis_name(ref)
      ref_mon = Process.monitor(pid)

      GenServer.stop(pid, :shutdown)
      assert_receive {:DOWN, ^ref_mon, :process, ^pid, :shutdown}, 500

      assert :ets.info(tid) == :undefined
    end
  end

  describe "pick_channel/2 racing disconnect/1" do
    test "concurrent picks either succeed or return :no_connection", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      {:ok, channel} =
        Connection.connect(target, adapter: adapter, name: ref, lb_policy: :round_robin)

      pickers =
        for _ <- 1..50 do
          Task.async(fn -> for _ <- 1..200, do: Connection.pick_channel(channel) end)
        end

      {:ok, _} = Connection.disconnect(channel)

      for result <- Enum.flat_map(pickers, &Task.await/1) do
        assert match?({:ok, %Channel{}}, result) or result == {:error, :no_connection}
      end

      assert {:error, :no_connection} = Connection.pick_channel(channel)
    end
  end

  describe "resource leaks over repeated connect/disconnect" do
    test "no persistent_term entries or LB tables are left behind", %{
      target: target,
      adapter: adapter
    } do
      tables_before = length(:ets.all())
      entries_before = connection_pt_count()

      for lb_policy <- [:pick_first, :round_robin], _ <- 1..250 do
        {:ok, channel} =
          Connection.connect(target, adapter: adapter, name: make_ref(), lb_policy: lb_policy)

        {:ok, _} = Connection.disconnect(channel)
      end

      assert connection_pt_count() == entries_before

      # disconnect/1 replies before the process exits, so the last few
      # tables may still be alive at this point.
      assert length(:ets.all()) - tables_before <= 5
    end
  end

  describe "connect/2 - distributed named channels" do
    test "named channels do not conflict across connected nodes" do
      {:ok, _, port} = GRPC.Server.start(FeatureServer, 0)

      on_exit(fn ->
        :ok = GRPC.Server.stop(FeatureServer)
      end)

      {peer1, node1} = start_peer()
      {peer2, node2} = start_peer()

      on_exit(fn ->
        stop_peer(peer1)
        stop_peer(peer2)
      end)

      assert :pong == @peer.call(peer1, :net_adm, :ping, [node2])
      assert :pong == @peer.call(peer2, :net_adm, :ping, [node1])
      assert :ok == @peer.call(peer1, :global, :sync, [])
      assert :ok == @peer.call(peer2, :global, :sync, [])

      target = "ipv4:127.0.0.1:#{port}"
      ref = :shared_channel

      assert {:ok, %Channel{ref: ^ref}} =
               @peer.call(peer1, Connection, :connect, [target, [name: ref]])

      assert {:ok, %Channel{ref: ^ref}} =
               @peer.call(peer2, Connection, :connect, [target, [name: ref]])
    end
  end

  defp connection_pt_count do
    Enum.count(:persistent_term.get(), &match?({{Connection, _}, _}, &1))
  end

  defp lb_tid(ref) do
    %{lb_state: %{tid: tid}} = :sys.get_state(whereis_name(ref))
    tid
  end

  defp start_peer do
    {:ok, peer, node} =
      @peer.start_link(%{
        name: @peer.random_name(~c"grpcpeer"),
        longnames: true,
        host: ~c"127.0.0.1",
        connection: :standard_io,
        args: [~c"-setcookie", ~c"grpcpeer"]
      })

    :ok = @peer.call(peer, :code, :add_paths, [:code.get_path()])
    {:ok, _apps} = @peer.call(peer, Application, :ensure_all_started, [:grpc])

    {peer, node}
  end

  defp stop_peer(peer) do
    @peer.stop(peer)
  catch
    :exit, _reason ->
      :ok
  end

  defp whereis_name(ref) do
    case Registry.lookup(GRPC.Client.Registry, {Connection, ref}) do
      [{pid, _value}] -> pid
      [] -> nil
    end
  end
end
