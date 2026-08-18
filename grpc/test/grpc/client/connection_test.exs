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
    test "returns {:error, :no_connection} when the ref was never published", %{ref: ref} do
      channel = %Channel{ref: ref}

      assert {:error, :no_connection} = Connection.pick_channel(channel)
    end

    test "returns {:ok, channel} by asking the load balancer", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)

      assert {:ok, ^channel} = Connection.pick_channel(%Channel{ref: ref})
    end

    test "picks without messaging the orchestrator", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)

      pid = whereis_name(ref)
      assert {:message_queue_len, 0} = Process.info(pid, :message_queue_len)

      Enum.each(1..100, fn _ -> assert {:ok, _} = Connection.pick_channel(channel) end)

      assert {:message_queue_len, 0} = Process.info(pid, :message_queue_len)
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

    test "pick_channel returns {:error, :no_connection} after disconnect", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)

      {:ok, _} = Connection.disconnect(channel)

      assert {:error, :no_connection} = Connection.pick_channel(channel)
    end

    test "the load balancer table is freed on disconnect", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)
      table = lb_table(ref)

      {:ok, _} = Connection.disconnect(channel)

      assert :ets.info(table) == :undefined
    end

    test "picks racing a disconnect never crash the caller", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)

      pickers =
        for _ <- 1..50 do
          Task.async(fn ->
            Enum.each(1..100, fn _ -> Connection.pick_channel(channel) end)
            :done
          end)
        end

      {:ok, _} = Connection.disconnect(channel)

      assert Enum.all?(Task.await_many(pickers, 5_000), &(&1 == :done))
    end
  end

  describe "terminate/2 - cleanup on process kill" do
    test "the published entry and the lb table are freed without disconnect", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)
      table = lb_table(ref)

      pid = whereis_name(ref)
      ref_mon = Process.monitor(pid)
      GenServer.stop(pid, :shutdown)
      assert_receive {:DOWN, ^ref_mon, :process, ^pid, :shutdown}, 500

      assert :ets.info(table) == :undefined
      assert :persistent_term.get({Connection, ref}, :erased) == :erased
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

  defp lb_table(ref) do
    ref |> whereis_name() |> :sys.get_state() |> Map.fetch!(:lb_state) |> Map.fetch!(:table)
  end
end
