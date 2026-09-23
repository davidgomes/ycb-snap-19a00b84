defmodule ObanChore.PluginTest do
  use ExUnit.Case, async: false

  defmodule TestChore do
    use ObanChore.Worker, name: "Plugin Test Chore", fields: [arg: [type: :string]]

    @impl Oban.Worker
    def perform(_), do: :ok
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

  test "registers only the explicitly configured chores" do
    {:ok, pid} = ObanChore.Plugin.start_link(chores: [TestChore], pubsub_server: TestPubSub)

    assert [%{module: TestChore, name: "Plugin Test Chore"}] = ObanChore.Plugin.get_chores()

    GenServer.stop(pid)
  end

  test "restarting the plugin refreshes the telemetry handler config" do
    {:ok, pid} = ObanChore.Plugin.start_link(chores: [], pubsub_server: TestPubSub)
    _ = :sys.get_state(pid)
    GenServer.stop(pid)

    {:ok, pid} = ObanChore.Plugin.start_link(chores: [TestChore], pubsub_server: TestPubSub)
    _ = :sys.get_state(pid)

    handler =
      Enum.find(:telemetry.list_handlers([:oban, :job, :start]), fn handler ->
        handler.id == {:oban_chore_counts, Oban}
      end)

    assert [%{module: TestChore}] = handler.config.chores

    GenServer.stop(pid)
  end

  test "get_chores/0 returns an empty list when the plugin is not running" do
    assert ObanChore.Plugin.get_chores() == []
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

    assert ObanChore.Plugin.validate(chores: [TestChore], pubsub_server: TestPubSub) == :ok

    assert {:error, "chores must be a list of modules"} =
             ObanChore.Plugin.validate(chores: TestChore, pubsub_server: TestPubSub)

    assert {:error, "all chores elements must be modules"} =
             ObanChore.Plugin.validate(
               chores: [TestChore, "NotAModule"],
               pubsub_server: TestPubSub
             )

    assert {:error, "pubsub_server must be an atom"} =
             ObanChore.Plugin.validate(pubsub_server: "TestPubSub")
  end
end
