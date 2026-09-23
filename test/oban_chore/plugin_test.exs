defmodule ObanChore.PluginTest do
  use ExUnit.Case, async: false

  alias ObanChore.TestChores.{FailingChore, UniqueReindex, UserBackfill}

  defmodule TestChore do
    use ObanChore.Worker, name: "Plugin Test Chore", fields: [arg: [type: :string]]

    @impl Oban.Worker
    def perform(_), do: :ok
  end

  defp start_plugin!(opts) do
    pid =
      start_supervised!(
        {ObanChore.Plugin, Keyword.put(opts, :pubsub_server, ObanChore.TestPubSub)}
      )

    # Wait for handle_continue to finish
    _ = :sys.get_state(pid)
    pid
  end

  test "get_chores/0 returns an empty list when the plugin isn't running" do
    assert ObanChore.Plugin.get_chores() == []
  end

  test "discovers chores across all loaded applications" do
    start_plugin!([])

    chores = ObanChore.Plugin.get_chores()
    assert is_list(chores)
    assert UserBackfill.__chore_info__() in chores
  end

  test "can limit discovery to a specific otp_app" do
    start_plugin!(otp_app: :oban_chore)

    modules = Enum.map(ObanChore.Plugin.get_chores(), & &1.module)
    assert UserBackfill in modules
    assert UniqueReindex in modules
    assert FailingChore in modules

    # Modules defined in test files are not part of the application's module list
    refute TestChore in modules
  end

  test "discovers nothing for applications without chores" do
    start_plugin!(otp_app: :logger)

    assert ObanChore.Plugin.get_chores() == []
  end

  test "registers an explicit list of chores, skipping discovery" do
    start_plugin!(chores: [TestChore, UserBackfill], otp_app: :logger)

    assert ObanChore.Plugin.get_chores() == [
             TestChore.__chore_info__(),
             UserBackfill.__chore_info__()
           ]
  end

  test "sets the pubsub server for the application" do
    start_plugin!(chores: [])

    assert ObanChore.pubsub_server() == ObanChore.TestPubSub
  end

  test "a restarted plugin replaces the telemetry handler of the previous one" do
    start_plugin!(chores: [TestChore])
    stop_supervised!(ObanChore.Plugin)
    start_plugin!(chores: [UserBackfill])

    assert [handler] =
             [:oban, :job, :start]
             |> :telemetry.list_handlers()
             |> Enum.filter(&(&1.id == {:oban_chore_counts, Oban}))

    assert handler.config.chores == [UserBackfill.__chore_info__()]
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

    assert {:error, "pubsub_server must be an atom"} =
             ObanChore.Plugin.validate(pubsub_server: "not_an_atom")
  end

  test "validate/1 checks the chores option" do
    assert ObanChore.Plugin.validate(chores: [], pubsub_server: TestPubSub) == :ok

    assert ObanChore.Plugin.validate(chores: [TestChore, UserBackfill], pubsub_server: TestPubSub) ==
             :ok

    assert {:error, "chores must be a list of modules"} =
             ObanChore.Plugin.validate(chores: TestChore, pubsub_server: TestPubSub)

    assert {:error, message} =
             ObanChore.Plugin.validate(chores: [TestChore, String], pubsub_server: TestPubSub)

    assert message =~ "String"
    refute message =~ "TestChore"
  end
end
