defmodule ObanChore.Test.Chores do
  @moduledoc false

  @runner :oban_chore_test_runner

  @doc """
  Registers the calling test process as the one that `checkpoint/1` reports to.
  """
  def register_runner, do: Process.register(self(), @runner)

  @doc """
  Blocks the job until the test process replies with `:continue`, so tests can
  observe (and subscribe to) a job before it finishes.
  """
  def checkpoint(%Oban.Job{id: id}) do
    send(@runner, {:job_started, id, self()})

    receive do
      :continue -> :ok
    after
      5_000 -> exit(:checkpoint_timeout)
    end
  end

  defmodule Greeter do
    @moduledoc false
    use ObanChore.Worker,
      name: "Greeter",
      description: "Says hello to someone.",
      fields: [
        name: [type: :string, required: true, label: "Name"],
        times: [type: :integer, default: 1, label: "Times"]
      ]

    @impl ObanChore.Worker
    def custom_changeset(changeset) do
      validate_number(changeset, :times, greater_than: 0)
    end

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"name" => name} = args} = job) do
      ObanChore.Test.Chores.checkpoint(job)

      for _ <- 1..Map.get(args, "times", 1) do
        ObanChore.log(job, "Hello, #{name}!")
      end

      :ok
    end
  end

  defmodule Failing do
    @moduledoc false
    use ObanChore.Worker, name: "Failing", max_attempts: 3, fields: []

    @impl Oban.Worker
    def perform(%Oban.Job{} = job) do
      ObanChore.Test.Chores.checkpoint(job)
      {:error, "boom"}
    end
  end

  # Runs on a queue that is never started, so its jobs stay `available`.
  defmodule Parked do
    @moduledoc false
    use ObanChore.Worker,
      name: "Parked",
      queue: :parked,
      fields: [user_id: [type: :integer, required: true, label: "User ID"]]

    @impl Oban.Worker
    def perform(_job), do: :ok
  end

  defmodule UniqueParked do
    @moduledoc false
    use ObanChore.Worker,
      name: "Unique Parked",
      queue: :parked,
      unique: [period: :infinity],
      fields: [account_id: [type: :integer, required: true, label: "Account ID"]]

    @impl Oban.Worker
    def perform(_job), do: :ok
  end
end
