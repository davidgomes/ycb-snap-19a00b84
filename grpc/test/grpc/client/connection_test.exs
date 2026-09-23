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

    test "returns {:ok, channel} when a channel is stored in persistent_term", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)

      assert {:ok, ^channel} = Connection.pick_channel(%Channel{ref: ref})
    end
  end

  describe "pick_channel/2 - per-request load balancing" do
    setup do
      on_exit(fn -> Application.delete_env(:grpc, :grpc_test_failing_hosts) end)
      %{multi_target: "ipv4:127.0.0.1:50051,127.0.0.2:50051"}
    end

    test "round_robin rotates across channels on every pick", ctx do
      {:ok, channel} =
        Connection.connect(ctx.multi_target,
          adapter: ctx.adapter,
          name: ctx.ref,
          lb_policy: :round_robin
        )

      assert pick_hosts(channel, 4) == ~w(127.0.0.1 127.0.0.2 127.0.0.1 127.0.0.2)

      Connection.disconnect(channel)
    end

    test "pick_first sticks to the first channel", ctx do
      {:ok, channel} = Connection.connect(ctx.multi_target, adapter: ctx.adapter, name: ctx.ref)

      assert pick_hosts(channel, 3) == ~w(127.0.0.1 127.0.0.1 127.0.0.1)

      Connection.disconnect(channel)
    end

    test "only channels that connected are picked", ctx do
      Application.put_env(:grpc, :grpc_test_failing_hosts, ["127.0.0.1"])

      {:ok, channel} =
        Connection.connect(ctx.multi_target,
          adapter: GRPC.Test.FailingClientAdapter,
          name: ctx.ref,
          lb_policy: :round_robin
        )

      assert channel.host == "127.0.0.2"
      assert pick_hosts(channel, 3) == ~w(127.0.0.2 127.0.0.2 127.0.0.2)

      Connection.disconnect(channel)
    end

    test "connect/2 returns the connect error when no channel connects", ctx do
      Application.put_env(:grpc, :grpc_test_failing_hosts, ["127.0.0.1", "127.0.0.2"])

      assert {:error, :connection_refused} =
               Connection.connect(ctx.multi_target,
                 adapter: GRPC.Test.FailingClientAdapter,
                 name: ctx.ref
               )

      assert {:error, :no_connection} = Connection.pick_channel(%Channel{ref: ctx.ref})
    end
  end

  describe "load balancer lifecycle" do
    test "outlives the process that called connect/2", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      parent = self()

      {pid, mon} =
        spawn_monitor(fn ->
          {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)
          send(parent, {:connected, channel})
        end)

      assert_receive {:connected, channel}
      assert_receive {:DOWN, ^mon, :process, ^pid, :normal}

      assert {:ok, ^channel} = Connection.pick_channel(channel)

      Connection.disconnect(channel)
    end

    test "disconnect/1 frees the load balancer table", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)
      %{lb_state: %{tid: tid}} = :sys.get_state(whereis_name(ref))

      {:ok, _} = Connection.disconnect(channel)

      assert :ets.info(tid) == :undefined
    end

    test "terminate/2 frees the load balancer table", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      {:ok, _channel} = Connection.connect(target, adapter: adapter, name: ref)
      pid = whereis_name(ref)
      %{lb_state: %{tid: tid}} = :sys.get_state(pid)

      ref_mon = Process.monitor(pid)
      GenServer.stop(pid, :shutdown)
      assert_receive {:DOWN, ^ref_mon, :process, ^pid, :shutdown}, 500

      assert :ets.info(tid) == :undefined
    end

    test "concurrent picks racing disconnect/1 fail with :no_connection, never crash", %{
      ref: ref,
      adapter: adapter
    } do
      {:ok, channel} =
        Connection.connect("ipv4:127.0.0.1:50051,127.0.0.2:50051",
          adapter: adapter,
          name: ref,
          lb_policy: :round_robin
        )

      pickers = for _ <- 1..50, do: Task.async(fn -> pick_until_disconnected(channel, 0) end)

      Process.sleep(10)
      {:ok, _} = Connection.disconnect(channel)

      assert Enum.all?(Task.await_many(pickers, 5_000), &(&1 > 0))
      assert {:error, :no_connection} = Connection.pick_channel(channel)
    end

    test "connect/disconnect cycles leak neither persistent_term entries nor ETS tables", %{
      target: target,
      adapter: adapter
    } do
      terms_before = connection_terms()
      tables_before = lb_tables()

      for policy <- [:pick_first, :round_robin], _ <- 1..100 do
        {:ok, channel} =
          Connection.connect(target, adapter: adapter, name: make_ref(), lb_policy: policy)

        {:ok, _} = Connection.disconnect(channel)
      end

      assert connection_terms() == terms_before
      assert lb_tables() == tables_before
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

  defp pick_hosts(channel, n) do
    for _ <- 1..n do
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

  defp connection_terms do
    for {{Connection, _} = key, _value} <- :persistent_term.get(), do: key
  end

  defp lb_tables do
    lb_mods = [GRPC.Client.LoadBalancing.PickFirst, GRPC.Client.LoadBalancing.RoundRobin]
    :ets.all() |> Enum.filter(&(:ets.info(&1, :name) in lb_mods)) |> Enum.sort()
  end
end
