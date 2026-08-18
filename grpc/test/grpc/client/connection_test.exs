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
      multi_target: "ipv4:10.0.0.1:50051,10.0.0.2:50051,10.0.0.3:50051",
      adapter: GRPC.Test.ClientAdapter
    }
  end

  describe "pick_channel/2" do
    test "returns {:error, :no_connection} when no persistent_term entry exists", %{ref: ref} do
      channel = %Channel{ref: ref}

      assert {:error, :no_connection} = Connection.pick_channel(channel)
    end

    test "returns {:ok, channel} when a channel is stored in persistent_term", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)

      assert {:ok, ^channel} = Connection.pick_channel(%Channel{ref: ref})
    end

    test "asks the load-balancing module on every call", %{
      ref: ref,
      multi_target: target,
      adapter: adapter
    } do
      {:ok, channel} =
        Connection.connect(target, adapter: adapter, name: ref, lb_policy: :round_robin)

      hosts =
        for _ <- 1..7 do
          {:ok, picked} = Connection.pick_channel(channel)
          picked.host
        end

      distinct = Enum.uniq(hosts)

      assert length(distinct) == 3
      assert hosts == distinct |> Stream.cycle() |> Enum.take(7)

      Connection.disconnect(channel)
    end

    test "concurrent pickers do not crash when the connection goes away", %{
      ref: ref,
      multi_target: target,
      adapter: adapter
    } do
      {:ok, channel} =
        Connection.connect(target, adapter: adapter, name: ref, lb_policy: :round_robin)

      pickers =
        for _ <- 1..50 do
          Task.async(fn ->
            Enum.map(1..100, fn _ -> Connection.pick_channel(channel) end)
          end)
        end

      Connection.disconnect(channel)

      results = pickers |> Task.await_many(5_000) |> List.flatten()

      assert Enum.all?(results, fn
               {:ok, %Channel{}} -> true
               {:error, :no_connection} -> true
               _other -> false
             end)
    end
  end

  describe "load balancing state" do
    test "persistent_term holds the policy and its state, keyed by channel ref", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)

      assert {GRPC.Client.LoadBalancing.PickFirst, lb_state} =
               :persistent_term.get({Connection, ref})

      assert %{table: table} = lb_state
      assert :ets.info(table, :owner) == whereis_name(ref)

      Connection.disconnect(channel)
    end

    test "re-resolution does not write to persistent_term", %{
      ref: ref,
      multi_target: target,
      adapter: adapter
    } do
      {:ok, channel} =
        Connection.connect(target, adapter: adapter, name: ref, lb_policy: :round_robin)

      published = :persistent_term.get({Connection, ref})

      send(
        whereis_name(ref),
        {:resolver_update, {:ok, %{addresses: [%{address: "10.0.0.9", port: 50051}]}}}
      )

      assert {:ok, %Channel{host: "10.0.0.9"}} = eventually_picks(channel, "10.0.0.9")
      assert :persistent_term.get({Connection, ref}) == published

      Connection.disconnect(channel)
    end
  end

  describe "resource cleanup" do
    test "disconnect frees the load balancer table", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)
      {_lb_mod, %{table: table}} = :persistent_term.get({Connection, ref})

      {:ok, _} = Connection.disconnect(channel)

      assert :ets.info(table) == :undefined
    end

    test "an abrupt stop frees the load balancer table", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      {:ok, _channel} = Connection.connect(target, adapter: adapter, name: ref)
      {_lb_mod, %{table: table}} = :persistent_term.get({Connection, ref})

      pid = whereis_name(ref)
      ref_mon = Process.monitor(pid)
      GenServer.stop(pid, :shutdown)
      assert_receive {:DOWN, ^ref_mon, :process, ^pid, :shutdown}, 500

      assert :ets.info(table) == :undefined
    end

    test "repeated connect/disconnect cycles leak neither terms nor tables", %{
      target: target,
      adapter: adapter
    } do
      terms_before = count_lb_terms()
      tables_before = count_lb_tables()

      for _ <- 1..100 do
        {:ok, channel} = Connection.connect(target, adapter: adapter, name: make_ref())
        {:ok, _} = Connection.disconnect(channel)
      end

      assert count_lb_terms() == terms_before
      assert count_lb_tables() == tables_before
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

  defp eventually_picks(channel, host, attempts \\ 50) do
    case Connection.pick_channel(channel) do
      {:ok, %Channel{host: ^host}} = picked ->
        picked

      _other when attempts > 0 ->
        Process.sleep(10)
        eventually_picks(channel, host, attempts - 1)

      other ->
        other
    end
  end

  defp count_lb_terms do
    Enum.count(:persistent_term.get(), &match?({{Connection, _ref}, _value}, &1))
  end

  defp count_lb_tables do
    Enum.count(:ets.all(), fn table ->
      :ets.info(table, :name) in [:grpc_lb_pick_first, :grpc_lb_round_robin]
    end)
  end
end
