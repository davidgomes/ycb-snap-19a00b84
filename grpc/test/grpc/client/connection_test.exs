defmodule GRPC.Client.ConnectionTest do
  use GRPC.Client.DataCase, async: false
  import Mox

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
    test "returns {:error, :no_connection} when no connection is registered for the ref", %{
      ref: ref
    } do
      channel = %Channel{ref: ref}

      assert {:error, :no_connection} = Connection.pick_channel(channel)
    end

    test "returns {:ok, channel} when a connection is registered for the ref", %{
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
      Mox.set_mox_global()

      stub(GRPC.Client.MockResolver, :resolve, fn _target ->
        {:ok,
         %{
           addresses: [%{address: "10.0.0.1", port: 50051}, %{address: "10.0.0.2", port: 50051}],
           service_config: nil
         }}
      end)

      stub(GRPC.Client.MockResolver, :init, fn _target, _opts -> {:ok, nil} end)
      :ok
    end

    test "round_robin rotates across backends on every pick", %{ref: ref, adapter: adapter} do
      channel = connect_multi(ref, adapter, :round_robin)

      assert pick_hosts(channel, 4) == ["10.0.0.1", "10.0.0.2", "10.0.0.1", "10.0.0.2"]

      Connection.disconnect(channel)
    end

    test "round_robin spreads concurrent picks evenly", %{ref: ref, adapter: adapter} do
      channel = connect_multi(ref, adapter, :round_robin)

      hosts =
        1..10
        |> Task.async_stream(fn _ -> pick_hosts(channel, 10) end)
        |> Enum.flat_map(fn {:ok, hosts} -> hosts end)

      assert Enum.frequencies(hosts) == %{"10.0.0.1" => 50, "10.0.0.2" => 50}

      Connection.disconnect(channel)
    end

    test "pick_first always returns the first backend", %{ref: ref, adapter: adapter} do
      channel = connect_multi(ref, adapter, :pick_first)

      assert pick_hosts(channel, 4) == List.duplicate("10.0.0.1", 4)

      Connection.disconnect(channel)
    end

    test "picks without calling the connection process", %{ref: ref, adapter: adapter} do
      channel = connect_multi(ref, adapter, :round_robin)
      pid = whereis_name(ref)

      :sys.suspend(pid)

      try do
        assert {:ok, %Channel{}} = Connection.pick_channel(channel)
      after
        :sys.resume(pid)
      end

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

    test "pick_channel returns {:error, :no_connection} right after disconnect",
         %{ref: ref, target: target, adapter: adapter} do
      {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)

      {:ok, _} = Connection.disconnect(channel)

      assert {:error, :no_connection} = Connection.pick_channel(channel)
    end
  end

  describe "terminate/2 - LB cleanup on process stop" do
    test "pick_channel fails when process is stopped without disconnect", %{
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

  defp connect_multi(ref, adapter, lb_policy) do
    {:ok, channel} =
      Connection.connect("dns://my-service.local:50051",
        adapter: adapter,
        name: ref,
        resolver: GRPC.Client.MockResolver,
        lb_policy: lb_policy
      )

    channel
  end

  defp pick_hosts(channel, count) do
    for _ <- 1..count do
      {:ok, %Channel{host: host}} = Connection.pick_channel(channel)
      host
    end
  end

  defp whereis_name(ref) do
    case Registry.lookup(GRPC.Client.Registry, {Connection, ref}) do
      [{pid, _value}] -> pid
      [] -> nil
    end
  end
end
