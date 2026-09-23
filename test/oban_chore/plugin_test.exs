defmodule ObanChore.PluginTest do
  use ExUnit.Case, async: false

  alias ObanChore.TestChores.{AccountCleanup, UserBackfill}

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
    # TestChore is defined in this test file, so it isn't part of the app's modules list,
    # while the chores in test/support are compiled into :oban_chore.
    {:ok, pid} = ObanChore.Plugin.start_link(otp_app: :oban_chore, pubsub_server: TestPubSub)

    # Wait for handle_continue to finish
    _ = :sys.get_state(pid)

    modules = Enum.map(ObanChore.Plugin.get_chores(), & &1.module)
    assert UserBackfill in modules
    assert AccountCleanup in modules
    refute TestChore in modules

    GenServer.stop(pid)
  end

  test "registers an explicit list of chores in the given order" do
    pid =
      start_supervised!(
        {ObanChore.Plugin, chores: [TestChore, AccountCleanup], pubsub_server: TestPubSub}
      )

    _ = :sys.get_state(pid)

    assert [
             %{module: TestChore, name: "Plugin Test Chore", unique: false},
             %{module: AccountCleanup, name: "Account Cleanup", unique: true}
           ] = ObanChore.Plugin.get_chores()
  end

  test "restarting the plugin replaces its telemetry handler" do
    start_supervised!({ObanChore.Plugin, chores: [UserBackfill], pubsub_server: TestPubSub})
    :ok = stop_supervised(ObanChore.Plugin)

    pid =
      start_supervised!({ObanChore.Plugin, chores: [AccountCleanup], pubsub_server: TestPubSub})

    _ = :sys.get_state(pid)

    assert [%{config: config}] =
             [:oban, :job, :start]
             |> :telemetry.list_handlers()
             |> Enum.filter(&(&1.id == {:oban_chore_counts, Oban}))

    assert Enum.map(config.chores, & &1.module) == [AccountCleanup]
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

  test "validate/1 checks the chores option" do
    assert ObanChore.Plugin.validate(chores: [UserBackfill], pubsub_server: TestPubSub) == :ok

    assert {:error, "all chores must use ObanChore.Worker, got: [String]"} =
             ObanChore.Plugin.validate(chores: [UserBackfill, String], pubsub_server: TestPubSub)

    assert {:error, "chores must be a list of modules"} =
             ObanChore.Plugin.validate(chores: UserBackfill, pubsub_server: TestPubSub)
  end
end
