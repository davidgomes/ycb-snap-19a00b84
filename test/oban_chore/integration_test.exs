defmodule ObanChore.IntegrationTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias ObanChore.TestRepo

  @pubsub ObanChore.IntegrationPubSub

  defmodule EchoChore do
    use ObanChore.Worker,
      name: "Echo Chore",
      queue: :default,
      fields: [user_id: [type: :integer, required: true]]

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"user_id" => user_id}} = job) do
      ObanChore.log(job, "Processing user #{user_id}")
      :ok
    end
  end

  defmodule UnregisteredChore do
    use ObanChore.Worker, name: "Unregistered Chore", queue: :default, fields: []

    @impl Oban.Worker
    def perform(_job), do: :ok
  end

  setup do
    :ok = Sandbox.checkout(TestRepo)
    start_supervised!({Phoenix.PubSub, name: @pubsub})
    start_supervised!({ObanChore.Plugin, pubsub_server: @pubsub, chores: [EchoChore]})

    # Blocks until the plugin has finished registering chores and telemetry handlers.
    _ = ObanChore.Plugin.get_chores()

    :ok
  end

  describe "queries against a real database" do
    test "count_running/2 only counts active jobs of the given worker" do
      Oban.insert!(EchoChore.new(%{user_id: 1}))
      Oban.insert!(EchoChore.new(%{user_id: 2}, schedule_in: 60))
      Oban.insert!(EchoChore.new(%{user_id: 3}) |> Ecto.Changeset.put_change(:state, "completed"))
      Oban.insert!(UnregisteredChore.new(%{}))

      assert ObanChore.count_running(EchoChore) == 2
      assert ObanChore.count_running(UnregisteredChore) == 1
    end

    test "running_with_args?/3 matches active jobs containing the given args" do
      Oban.insert!(EchoChore.new(%{user_id: 1}))
      Oban.insert!(EchoChore.new(%{user_id: 2}) |> Ecto.Changeset.put_change(:state, "discarded"))

      assert ObanChore.running_with_args?(EchoChore, %{user_id: 1})
      assert ObanChore.running_with_args?(EchoChore, %{"user_id" => 1})
      refute ObanChore.running_with_args?(EchoChore, %{user_id: 2})
      refute ObanChore.running_with_args?(UnregisteredChore, %{user_id: 1})
    end

    test "list_active_jobs/2 returns active jobs with atom states" do
      %{id: available_id} = Oban.insert!(EchoChore.new(%{user_id: 1}))
      %{id: scheduled_id} = Oban.insert!(EchoChore.new(%{user_id: 2}, schedule_in: 60))
      Oban.insert!(EchoChore.new(%{user_id: 3}) |> Ecto.Changeset.put_change(:state, "cancelled"))

      states =
        EchoChore
        |> ObanChore.list_active_jobs()
        |> Map.new(&{&1.id, &1.state})

      assert states == %{available_id => :available, scheduled_id => :scheduled}
    end
  end

  describe "job execution" do
    test "broadcasts status changes, counts and logs for registered chores" do
      %{id: job_id} = Oban.insert!(EchoChore.new(%{user_id: 42}))

      Phoenix.PubSub.subscribe(@pubsub, "oban_chore:counts")
      Phoenix.PubSub.subscribe(@pubsub, "oban_chore:status:#{job_id}")
      Phoenix.PubSub.subscribe(@pubsub, "oban_chore:logs:#{job_id}")

      assert %{success: 1} = Oban.drain_queue(queue: :default)

      assert_receive {:oban_chore_state, ^job_id, :executing}
      assert_receive {:oban_chore_log, ^job_id, "Processing user 42"}
      assert_receive {:oban_chore_state, ^job_id, :completed}
      assert_receive {:oban_chore_count, EchoChore, _count}

      assert ObanChore.count_running(EchoChore) == 0
    end

    test "ignores jobs of workers that are not registered chores" do
      %{id: job_id} = Oban.insert!(UnregisteredChore.new(%{}))

      Phoenix.PubSub.subscribe(@pubsub, "oban_chore:counts")
      Phoenix.PubSub.subscribe(@pubsub, "oban_chore:status:#{job_id}")

      assert %{success: 1} = Oban.drain_queue(queue: :default)

      refute_receive {:oban_chore_state, ^job_id, _}
      refute_receive {:oban_chore_count, _, _}
    end
  end
end
