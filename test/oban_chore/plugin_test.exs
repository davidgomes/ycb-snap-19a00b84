defmodule ObanChore.PluginTest do
  use ExUnit.Case, async: false

  defmodule TestChore do
    use ObanChore.Worker, name: "Plugin Test Chore", fields: [arg: [type: :string]]

    @impl Oban.Worker
    def perform(_), do: :ok
  end

  defmodule OtherChore do
    use ObanChore.Worker, name: "Other Plugin Chore", fields: []

    @impl Oban.Worker
    def perform(_), do: :ok
  end

  setup do
    on_exit(fn ->
      :telemetry.detach({:oban_chore_counts, Oban})
      :telemetry.detach({:oban_chore_counts, ObanChore.PluginTest.Oban})
      Application.delete_env(:oban_chore, :pubsub_server)
    end)
  end

  test "discovers chores defined in the configured otp_app" do
    load_app(:oban_chore_plugin_test_app, [TestChore, __MODULE__, String])

    start_supervised!(
      {ObanChore.Plugin, otp_app: :oban_chore_plugin_test_app, pubsub_server: TestPubSub}
    )

    assert ObanChore.Plugin.get_chores() == [TestChore.__chore_info__()]
  end

  test "discovers chores across a list of otp_apps" do
    load_app(:oban_chore_plugin_test_app_a, [TestChore])
    load_app(:oban_chore_plugin_test_app_b, [OtherChore])

    start_supervised!(
      {ObanChore.Plugin,
       otp_app: [:oban_chore_plugin_test_app_a, :oban_chore_plugin_test_app_b],
       pubsub_server: TestPubSub}
    )

    assert ObanChore.Plugin.get_chores() == [
             TestChore.__chore_info__(),
             OtherChore.__chore_info__()
           ]
  end

  test "get_chores/0 returns an empty list when the plugin is not running" do
    refute GenServer.whereis(ObanChore.Plugin)
    assert ObanChore.Plugin.get_chores() == []
  end

  test "stores the pubsub server for ObanChore to broadcast on" do
    start_supervised!({ObanChore.Plugin, otp_app: :oban_chore, pubsub_server: TestPubSub})

    assert ObanChore.pubsub_server() == TestPubSub
  end

  test "attaches job telemetry handlers for the Oban instance it runs under" do
    start_supervised!(
      {ObanChore.Plugin,
       otp_app: :oban_chore, pubsub_server: TestPubSub, conf: %{name: ObanChore.PluginTest.Oban}}
    )

    _ = :sys.get_state(ObanChore.Plugin)

    handler_events =
      for handler <- :telemetry.list_handlers([:oban, :job]),
          handler.id == {:oban_chore_counts, ObanChore.PluginTest.Oban},
          do: handler.event_name

    assert Enum.sort(handler_events) == [
             [:oban, :job, :exception],
             [:oban, :job, :insert, :stop],
             [:oban, :job, :start],
             [:oban, :job, :stop]
           ]
  end

  test "discover_chores returns a list" do
    # Discovery might return empty if no chores are in lib/
    # but it should at least not crash.
    {:ok, pid} = ObanChore.Plugin.start_link(pubsub_server: TestPubSub)

    # Wait for handle_continue to finish
    _ = :sys.get_state(pid)

    chores = ObanChore.Plugin.get_chores()
    assert is_list(chores)
    GenServer.stop(pid)
  end

  test "can limit discovery to a specific otp_app" do
    # :oban_chore app should have some modules.
    # We don't necessarily expect TestChore to be found because it's defined in the test
    # and not in the .app modules list, but we can verify the GenServer starts and runs discovery.
    {:ok, pid} = ObanChore.Plugin.start_link(otp_app: :oban_chore, pubsub_server: TestPubSub)

    # Wait for handle_continue to finish
    _ = :sys.get_state(pid)

    chores = ObanChore.Plugin.get_chores()
    assert is_list(chores)

    GenServer.stop(pid)
  end

  test "validate/1 checks for correct format" do
    assert ObanChore.Plugin.validate(pubsub_server: TestPubSub) == :ok
    assert ObanChore.Plugin.validate(otp_app: :my_app, pubsub_server: TestPubSub) == :ok
    assert ObanChore.Plugin.validate(otp_app: [:app1, :app2], pubsub_server: TestPubSub) == :ok
    assert {:error, "missing :pubsub_server option"} = ObanChore.Plugin.validate([])

    assert {:error, _} =
             ObanChore.Plugin.validate(otp_app: "not_an_atom", pubsub_server: TestPubSub)

    assert {:error, _} =
             ObanChore.Plugin.validate(otp_app: [:app1, "not_an_atom"], pubsub_server: TestPubSub)
  end

  test "validate/1 explains what is wrong with invalid options" do
    assert ObanChore.Plugin.validate(otp_app: "my_app", pubsub_server: TestPubSub) ==
             {:error, "otp_app must be an atom or a list of atoms"}

    assert ObanChore.Plugin.validate(otp_app: [:app1, "app2"], pubsub_server: TestPubSub) ==
             {:error, "all otp_app elements must be atoms"}

    assert ObanChore.Plugin.validate(pubsub_server: "TestPubSub") ==
             {:error, "pubsub_server must be an atom"}
  end

  defp load_app(app, modules) do
    spec = [description: ~c"ObanChore test app", vsn: ~c"0.0.0", modules: modules]
    :ok = :application.load({:application, app, spec})
    on_exit(fn -> :application.unload(app) end)
  end
end
