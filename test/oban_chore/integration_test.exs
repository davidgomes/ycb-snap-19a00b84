defmodule ObanChore.IntegrationTest do
  use ExUnit.Case, async: false

  alias ObanChore.TestRepo
  import Ecto.Query

  defmodule IntegrationTestChore do
    use ObanChore.Worker,
      name: "Integration Test Chore",
      queue: :default,
      fields: [user_id: [type: :integer]]

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"user_id" => 999}}) do
      {:error, "invalid user"}
    end

    def perform(_job) do
      :ok
    end
  end

  setup do
    # Explicitly checkout connection for sandbox testing
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(TestRepo)

    # Use a unique name for the Oban instance to prevent registry name clashes
    oban_name = Module.concat([__MODULE__, "Oban", inspect(System.unique_integer([:positive]))])

    start_supervised!({
      Oban,
      # Use manual testing mode so jobs stay in the database and can be queried
      name: oban_name,
      repo: TestRepo,
      queues: [default: 5],
      notifier: Oban.Notifiers.Isolated,
      peer: Oban.Peers.Isolated,
      plugins: [],
      testing: :manual
    })

    {:ok, oban_name: oban_name}
  end

  test "count_running/2 counts active jobs", %{oban_name: oban_name} do
    # No jobs enqueued initially
    assert ObanChore.count_running(IntegrationTestChore, oban_name) == 0

    # Insert a job in the available state
    changeset = IntegrationTestChore.new(%{user_id: 123})
    {:ok, _job} = Oban.insert(oban_name, changeset)

    # In inline testing mode, inserting a job runs it immediately. 
    # Let's override the state to available manually to simulate an active job.
    TestRepo.update_all(Oban.Job, set: [state: "available"])

    assert ObanChore.count_running(IntegrationTestChore, oban_name) == 1
  end

  test "running_with_args?/3 checks if job with matching args exists", %{oban_name: oban_name} do
    changeset = IntegrationTestChore.new(%{user_id: 456})
    {:ok, _job} = Oban.insert(oban_name, changeset)

    # Keep the job in executing state to count as active
    TestRepo.update_all(Oban.Job, set: [state: "executing"])

    assert ObanChore.running_with_args?(IntegrationTestChore, %{user_id: 456}, oban_name)
    refute ObanChore.running_with_args?(IntegrationTestChore, %{user_id: 999}, oban_name)
  end

  test "list_active_jobs/2 returns jobs with atomized states ordered by id desc", %{oban_name: oban_name} do
    changeset1 = IntegrationTestChore.new(%{user_id: 789})
    {:ok, job1} = Oban.insert(oban_name, changeset1)

    changeset2 = IntegrationTestChore.new(%{user_id: 101112})
    {:ok, job2} = Oban.insert(oban_name, changeset2)

    # Manually update to completed and scheduled to test atom state conversion for all states
    TestRepo.update_all(where(Oban.Job, [j], j.id == ^job1.id), set: [state: "completed"])
    TestRepo.update_all(where(Oban.Job, [j], j.id == ^job2.id), set: [state: "scheduled"])

    jobs = ObanChore.list_active_jobs(IntegrationTestChore, oban_name)
    assert length(jobs) == 2

    [first_job, second_job] = jobs
    assert first_job.id == job2.id
    assert first_job.state == :scheduled

    assert second_job.id == job1.id
    assert second_job.state == :completed
  end
end
