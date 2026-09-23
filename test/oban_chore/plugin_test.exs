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
    # TestChore is defined in this test file and is not in the .app modules list,
    # but the chores compiled from test/support are.
    {:ok, pid} = ObanChore.Plugin.start_link(otp_app: :oban_chore, pubsub_server: TestPubSub)

    # Wait for handle_continue to finish
    _ = :sys.get_state(pid)

    modules = Enum.map(ObanChore.Plugin.get_chores(), & &1.module)
    assert ObanChore.Test.Chores.UserBackfill in modules
    assert ObanChore.Test.Chores.UniqueCleanup in modules
    refute TestChore in modules

    GenServer.stop(pid)
  end

  test "uses the explicit :chores list instead of discovery" do
    start_supervised!(
      {ObanChore.Plugin, otp_app: :oban_chore, chores: [TestChore], pubsub_server: TestPubSub}
    )

    assert [%{module: TestChore, name: "Plugin Test Chore", fields: [arg: [type: :string]]}] =
             ObanChore.Plugin.get_chores()
  end

  test "detaches its telemetry handler when stopped" do
    pid = start_supervised!({ObanChore.Plugin, chores: [TestChore], pubsub_server: TestPubSub})
    _ = :sys.get_state(pid)

    assert handler_attached?()

    stop_supervised!(ObanChore.Plugin)

    refute handler_attached?()
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

  test "validate/1 checks the :chores option" do
    assert ObanChore.Plugin.validate(chores: [TestChore], pubsub_server: TestPubSub) == :ok
    assert ObanChore.Plugin.validate(chores: [], pubsub_server: TestPubSub) == :ok

    assert {:error, "not chore modules: [String, NotAModule]"} =
             ObanChore.Plugin.validate(
               chores: [TestChore, String, NotAModule],
               pubsub_server: TestPubSub
             )

    assert {:error, _} = ObanChore.Plugin.validate(chores: TestChore, pubsub_server: TestPubSub)
  end

  defp handler_attached? do
    [:oban, :job, :start]
    |> :telemetry.list_handlers()
    |> Enum.any?(&(&1.id == {:oban_chore_counts, Oban}))
  end
end
