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
    # Chores in test/support are compiled into the :oban_chore app, while TestChore is
    # defined in this test file and isn't part of the app's modules list.
    {:ok, pid} = ObanChore.Plugin.start_link(otp_app: :oban_chore, pubsub_server: TestPubSub)

    # Wait for handle_continue to finish
    _ = :sys.get_state(pid)

    modules = Enum.map(ObanChore.Plugin.get_chores(), & &1.module)
    assert ObanChore.Test.Chores.Greeter in modules
    assert ObanChore.Test.Chores.Parked in modules
    refute TestChore in modules

    GenServer.stop(pid)
  end

  test "uses the :chores list instead of discovering chores" do
    {:ok, pid} = ObanChore.Plugin.start_link(chores: [TestChore], pubsub_server: TestPubSub)

    # Wait for handle_continue to finish
    _ = :sys.get_state(pid)

    assert [%{module: TestChore, name: "Plugin Test Chore", unique: false}] =
             ObanChore.Plugin.get_chores()

    GenServer.stop(pid)
  end

  test "validate/1 checks the :chores option" do
    assert ObanChore.Plugin.validate(chores: [TestChore], pubsub_server: TestPubSub) == :ok
    assert ObanChore.Plugin.validate(chores: [], pubsub_server: TestPubSub) == :ok

    assert {:error, "chores must be a list of modules"} =
             ObanChore.Plugin.validate(chores: TestChore, pubsub_server: TestPubSub)

    assert {:error, message} =
             ObanChore.Plugin.validate(chores: [TestChore, String], pubsub_server: TestPubSub)

    assert message =~ "String"
    refute message =~ "TestChore"
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
end
