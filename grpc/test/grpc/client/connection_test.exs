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
    test "returns {:error, :no_connection} when the connection does not exist", %{ref: ref} do
      channel = %Channel{ref: ref}

      assert {:error, :no_connection} = Connection.pick_channel(channel)
    end

    test "returns {:ok, channel} for a connected channel", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)

      assert {:ok, ^channel} = Connection.pick_channel(%Channel{ref: ref})
    end

    test "round robin rotates across backends on every pick", %{ref: ref, adapter: adapter} do
      {:ok, channel} =
        Connection.connect("ipv4:127.0.0.1:50051,127.0.0.2:50051,127.0.0.3:50051",
          adapter: adapter,
          name: ref,
          lb_policy: :round_robin
        )

      hosts =
        for _ <- 1..6 do
          {:ok, picked} = Connection.pick_channel(channel)
          picked.host
        end

      assert Enum.frequencies(hosts) == %{"127.0.0.1" => 2, "127.0.0.2" => 2, "127.0.0.3" => 2}

      Connection.disconnect(channel)
    end

    test "pick first keeps returning the first backend", %{ref: ref, adapter: adapter} do
      {:ok, channel} =
        Connection.connect("ipv4:127.0.0.1:50051,127.0.0.2:50051",
          adapter: adapter,
          name: ref,
          lb_policy: :pick_first
        )

      for _ <- 1..5 do
        assert {:ok, %Channel{host: "127.0.0.1"}} = Connection.pick_channel(channel)
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

    test "pick_channel returns {:error, :no_connection} after disconnect",
         %{ref: ref, target: target, adapter: adapter} do
      {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)

      {:ok, _} = Connection.disconnect(channel)

      assert {:error, :no_connection} = Connection.pick_channel(channel)
    end

    test "frees the load balancer's ETS table", %{ref: ref, target: target, adapter: adapter} do
      {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)
      %{lb_state: %{tid: tid}} = :sys.get_state(whereis_name(ref))

      {:ok, _} = Connection.disconnect(channel)

      assert :undefined == :ets.info(tid)
    end

    test "concurrent picks during disconnect never crash", %{ref: ref, adapter: adapter} do
      {:ok, channel} =
        Connection.connect("ipv4:127.0.0.1:50051,127.0.0.2:50051",
          adapter: adapter,
          name: ref,
          lb_policy: :round_robin
        )

      pickers =
        for _ <- 1..50 do
          Task.async(fn ->
            for _ <- 1..100, do: Connection.pick_channel(channel)
          end)
        end

      {:ok, _} = Connection.disconnect(channel)

      for result <- pickers |> Task.await_many() |> List.flatten() do
        assert match?({:ok, %Channel{}}, result) or result == {:error, :no_connection}
      end
    end

    test "repeated connect/disconnect cycles leak no persistent_term entries or ETS tables",
         %{target: target, adapter: adapter} do
      count_entries = fn ->
        Enum.count(:persistent_term.get(), &match?({{Connection, _}, _}, &1))
      end

      entries_before = count_entries.()
      tables_before = length(:ets.all())

      for _ <- 1..200 do
        {:ok, channel} = Connection.connect(target, adapter: adapter, name: make_ref())
        pid = whereis_name(channel.ref)
        ref_mon = Process.monitor(pid)
        {:ok, _} = Connection.disconnect(channel)
        assert_receive {:DOWN, ^ref_mon, :process, ^pid, _}, 500
      end

      assert count_entries.() == entries_before
      # a leak would add one table per cycle; allow slack for unrelated tables
      assert length(:ets.all()) - tables_before < 10
    end
  end

  describe "terminate/2 - cleanup on process kill" do
    test "pick_channel fails when process is stopped without disconnect", %{
      ref: ref,
      target: target,
      adapter: adapter
    } do
      {:ok, channel} = Connection.connect(target, adapter: adapter, name: ref)

      pid = whereis_name(ref)
      %{lb_state: %{tid: tid}} = :sys.get_state(pid)
      ref_mon = Process.monitor(pid)
      GenServer.stop(pid, :shutdown)
      assert_receive {:DOWN, ^ref_mon, :process, ^pid, :shutdown}, 500

      assert {:error, :no_connection} = Connection.pick_channel(channel)
      assert :undefined == :ets.info(tid)
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
end
