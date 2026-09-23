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

  describe "with chores in an otp_app" do
    @app :oban_chore_plugin_test
    @oban ObanChore.PluginTest.Oban

    setup do
      # TestChore is defined in this file, so it is registered through an ad-hoc application.
      modules = [TestChore, __MODULE__, ObanChore.PluginTest.NotLoaded]
      :ok = :application.load({:application, @app, [modules: modules]})
      start_supervised!({Phoenix.PubSub, name: TestPubSub})

      on_exit(fn ->
        :telemetry.detach({:oban_chore_counts, @oban})
        :application.unload(@app)
        Application.delete_env(:oban_chore, :pubsub_server)
      end)
    end

    test "discovers only the modules that use ObanChore.Worker" do
      start_supervised!({ObanChore.Plugin, otp_app: @app, pubsub_server: TestPubSub})

      assert ObanChore.Plugin.get_chores() == [TestChore.__chore_info__()]
      assert ObanChore.pubsub_server() == TestPubSub
    end

    test "broadcasts state and counts for chore jobs of its Oban instance" do
      start_supervised!(
        {Oban,
         name: @oban,
         repo: ObanChore.Test.MockRepo,
         testing: :inline,
         notifier: Oban.Notifiers.Isolated}
      )

      pid =
        start_supervised!(
          {ObanChore.Plugin, otp_app: @app, pubsub_server: TestPubSub, conf: %{name: @oban}}
        )

      # Wait for handle_continue to finish
      _ = :sys.get_state(pid)

      ObanChore.Test.MockRepo.stub(:aggregate, 1)
      Phoenix.PubSub.subscribe(TestPubSub, "oban_chore:status:7")
      Phoenix.PubSub.subscribe(TestPubSub, "oban_chore:counts")

      job = %Oban.Job{id: 7, worker: "ObanChore.PluginTest.TestChore", state: "executing"}
      :telemetry.execute([:oban, :job, :start], %{}, %{conf: %{name: @oban}, job: job})

      assert_receive {:oban_chore_state, 7, :executing}
      assert_receive {:oban_chore_count, TestChore, 1}
    end
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
  end
end
