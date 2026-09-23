defmodule GRPC.Client.ConnectionTest do
  use GRPC.Client.DataCase, async: false

  alias GRPC.Channel
  alias GRPC.Client.Connection

  @peer if Code.ensure_loaded?(:peer), do: :peer, else: GRPC.Test.PeerShim
  @multi_target "ipv4:10.0.0.1:50051,10.0.0.2:50051"

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

    test "returns {:ok, channel} for a live connection", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)

      assert {:ok, ^channel} = Connection.pick_channel(%Channel{ref: ref})
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

    test "the LB table is freed when the process is stopped", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      {:ok, _channel} = Connection.connect(target, adapter: adapter, name: ref)

      pid = whereis_name(ref)
      %{lb_state: %{tid: tid}} = :sys.get_state(pid)
      assert :ets.info(tid) != :undefined

      ref_mon = Process.monitor(pid)
      GenServer.stop(pid, :shutdown)
      assert_receive {:DOWN, ^ref_mon, :process, ^pid, :shutdown}, 500

      assert :ets.info(tid) == :undefined
    end
  end

  describe "per-request load balancing" do
    test "round_robin rotates across backends on every pick", %{ref: ref, adapter: adapter} do
      {:ok, channel} =
        Connection.connect(@multi_target, adapter: adapter, name: ref, lb_policy: :round_robin)

      assert picked_hosts(channel, 4) |> Enum.frequencies() ==
               %{"10.0.0.1" => 2, "10.0.0.2" => 2}

      Connection.disconnect(channel)
    end

    test "pick_first sends every pick to the first backend", %{ref: ref, adapter: adapter} do
      {:ok, channel} = Connection.connect(@multi_target, adapter: adapter, name: ref)

      assert Enum.uniq(picked_hosts(channel, 4)) == ["10.0.0.1"]

      Connection.disconnect(channel)
    end

    test "connect succeeds when only a later backend is reachable", %{ref: ref} do
      Application.put_env(:grpc, :grpc_test_failing_hosts, ["10.0.0.1"])
      on_exit(fn -> Application.delete_env(:grpc, :grpc_test_failing_hosts) end)

      {:ok, channel} =
        Connection.connect(@multi_target,
          adapter: GRPC.Test.FailingClientAdapter,
          name: ref,
          lb_policy: :round_robin
        )

      assert channel.host == "10.0.0.2"
      assert Enum.uniq(picked_hosts(channel, 4)) == ["10.0.0.2"]

      Connection.disconnect(channel)
    end

    test "connect returns the connection error when no backend is reachable", %{ref: ref} do
      Application.put_env(:grpc, :grpc_test_failing_hosts, ["10.0.0.1", "10.0.0.2"])
      on_exit(fn -> Application.delete_env(:grpc, :grpc_test_failing_hosts) end)

      assert {:error, :connection_refused} =
               Connection.connect(@multi_target,
                 adapter: GRPC.Test.FailingClientAdapter,
                 name: ref
               )

      assert whereis_name(ref) == nil
    end
  end

  describe "LB state lifecycle" do
    test "disconnect/1 frees the LB table", %{ref: ref, target: target, adapter: adapter} do
      {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)
      %{lb_state: %{tid: tid}} = :sys.get_state(whereis_name(ref))

      {:ok, _} = Connection.disconnect(channel)

      assert :ets.info(tid) == :undefined
    end

    test "picks racing disconnect/1 return a channel or :no_connection, never crash", %{
      ref: ref,
      adapter: adapter
    } do
      {:ok, channel} =
        Connection.connect(@multi_target, adapter: adapter, name: ref, lb_policy: :round_robin)

      parent = self()

      pickers =
        for _ <- 1..50 do
          Task.async(fn ->
            {:ok, %Channel{}} = Connection.pick_channel(channel)
            send(parent, :picking)
            pick_until_disconnected(channel, 1)
          end)
        end

      for _ <- pickers, do: assert_receive(:picking, 1_000)

      {:ok, _} = Connection.disconnect(channel)

      assert Enum.all?(Task.await_many(pickers, 5_000), &(&1 > 0))
      assert {:error, :no_connection} = Connection.pick_channel(channel)
    end

    test "connect/disconnect cycles leak neither persistent_term entries nor LB tables", %{
      target: target,
      adapter: adapter
    } do
      entries_before = connection_entry_count()
      tables_before = lb_table_count()

      for _ <- 1..500 do
        {:ok, channel} = Connection.connect(target, adapter: adapter, name: make_ref())
        {:ok, _} = Connection.disconnect(channel)
      end

      assert connection_entry_count() == entries_before
      assert lb_table_count() == tables_before
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

  defp picked_hosts(channel, count) do
    for _ <- 1..count do
      {:ok, %Channel{host: host}} = Connection.pick_channel(channel)
      host
    end
  end

  defp pick_until_disconnected(channel, picks) do
    case Connection.pick_channel(channel) do
      {:ok, %Channel{}} -> pick_until_disconnected(channel, picks + 1)
      {:error, :no_connection} -> picks
    end
  end

  defp connection_entry_count do
    Enum.count(:persistent_term.get(), &match?({{Connection, _ref}, _value}, &1))
  end

  defp lb_table_count do
    lb_mods = [GRPC.Client.LoadBalancing.PickFirst, GRPC.Client.LoadBalancing.RoundRobin]
    Enum.count(:ets.all(), &(:ets.info(&1, :name) in lb_mods))
  end
end
