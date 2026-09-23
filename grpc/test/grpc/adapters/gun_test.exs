defmodule GRPC.Client.Adapters.GunTest do
  use GRPC.Client.DataCase, async: true

  alias GRPC.Client.Adapters.Gun

  setup do
    server_credential = build(:credential)

    {:ok, _, port} =
      GRPC.Server.start(FeatureServer, 0, adapter_opts: [cred: server_credential])

    on_exit(fn ->
      :ok = GRPC.Server.stop(FeatureServer)
    end)

    %{
      port: port,
      credential: server_credential
    }
  end

  describe "connect/2" do
    test "connects insecurely (default options)", %{port: port, credential: credential} do
      channel = build(:channel, port: port, host: "localhost", cred: credential)

      assert {:ok, result} = Gun.connect(channel, [])

      assert %{channel | adapter_payload: %{conn_pid: result.adapter_payload.conn_pid}} == result
    end

    test "connects insecurely (custom options)", %{port: port, credential: credential} do
      channel = build(:channel, port: port, host: "localhost", cred: credential)

      # Ensure that it works
      assert {:ok, result} = Gun.connect(channel, transport_opts: [ip: :loopback])
      assert %{channel | adapter_payload: %{conn_pid: result.adapter_payload.conn_pid}} == result

      # Ensure that changing one of the options breaks things
      assert {:error, {:down, :badarg}} ==
               Gun.connect(channel, transport_opts: [ip: "256.0.0.0"])
    end

    test "connects securely (default options)", %{port: port, credential: credential} do
      channel =
        build(:channel,
          port: port,
          scheme: "https",
          host: "localhost",
          cred: credential
        )

      assert {:ok, result} = Gun.connect(channel, tls_opts: channel.cred.ssl)

      assert %{channel | adapter_payload: %{conn_pid: result.adapter_payload.conn_pid}} == result
    end

    test "connects securely (custom options)", %{port: port, credential: credential} do
      channel =
        build(:channel,
          port: port,
          scheme: "https",
          host: "localhost",
          cred: credential
        )

      # Ensure that it works
      assert {:ok, result} =
               Gun.connect(channel,
                 transport_opts: [
                   verify: :verify_none,
                   certfile: credential.ssl[:certfile],
                   ip: :loopback
                 ]
               )

      assert %{channel | adapter_payload: %{conn_pid: result.adapter_payload.conn_pid}} == result

      # Ensure that changing one of the options breaks things
      assert {:error, :timeout} ==
               Gun.connect(channel,
                 transport_opts: [
                   certfile: credential.ssl[:certfile] <> "invalidsuffix",
                   verify: :verify_peer,
                   ip: :loopback
                 ]
               )
    end

    test "reuses the connection for the same channel name", %{port: port, credential: credential} do
      channel = build(:channel, port: port, host: "localhost", cred: credential, ref: make_ref())

      assert {:ok, first} = Gun.connect(channel, [])
      assert {:ok, second} = Gun.connect(channel, [])

      assert first.adapter_payload.conn_pid == second.adapter_payload.conn_pid
    end

    test "the connection stops when its Gun process goes away", %{
      port: port,
      credential: credential
    } do
      channel = build(:channel, port: port, host: "localhost", cred: credential)

      {:ok, connected} = Gun.connect(channel, [])
      %{conn_pid: conn_pid} = connected.adapter_payload
      %{gun_pid: gun_pid} = :sys.get_state(conn_pid)
      monitor_ref = Process.monitor(conn_pid)

      Process.exit(gun_pid, :kill)

      assert_receive {:DOWN, ^monitor_ref, :process, ^conn_pid, :normal}, 500
    end
  end

  describe "disconnect/1" do
    test "keeps adapter_payload as a map with conn_pid set to nil", %{
      port: port,
      credential: credential
    } do
      channel = build(:channel, port: port, host: "localhost", cred: credential)

      {:ok, connected} = Gun.connect(channel, [])
      assert %{conn_pid: pid} = connected.adapter_payload
      assert is_pid(pid)

      {:ok, disconnected} = Gun.disconnect(connected)

      assert %{conn_pid: nil} = disconnected.adapter_payload
    end

    test "disconnect is idempotent — calling it twice succeeds", %{
      port: port,
      credential: credential
    } do
      channel = build(:channel, port: port, host: "localhost", cred: credential)

      {:ok, connected} = Gun.connect(channel, [])
      {:ok, disconnected} = Gun.disconnect(connected)
      {:ok, disconnected_again} = Gun.disconnect(disconnected)

      assert %{conn_pid: nil} = disconnected_again.adapter_payload
    end

    test "connecting again with the same channel name opens a new connection", %{
      port: port,
      credential: credential
    } do
      channel = build(:channel, port: port, host: "localhost", cred: credential, ref: make_ref())

      {:ok, connected} = Gun.connect(channel, [])
      {:ok, _disconnected} = Gun.disconnect(connected)
      {:ok, reconnected} = Gun.connect(channel, [])

      assert reconnected.adapter_payload.conn_pid != connected.adapter_payload.conn_pid
      assert Process.alive?(reconnected.adapter_payload.conn_pid)

      {:ok, _} = Gun.disconnect(reconnected)
    end
  end
end
