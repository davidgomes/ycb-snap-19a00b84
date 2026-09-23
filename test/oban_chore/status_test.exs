defmodule ObanChore.StatusTest do
  use ExUnit.Case, async: false

  @moduletag :capture_log

  @worker_str "ObanChore.StatusTest.TestWorker"
  @chores [%{module: ObanChore.StatusTest.TestWorker, name: "Test Worker"}]

  setup do
    # Ensure PubSub is configured for the test
    Application.put_env(:oban_chore, :pubsub_server, ObanChore.TestPubSub)

    # Start a dummy PubSub for testing if not already started
    # In a real project, this would be in test_helper.exs or supervised
    start_supervised!({Phoenix.PubSub, name: ObanChore.TestPubSub})

    :ok
  end

  test "telemetry broadcasts job state changes" do
    job_id = 456
    # Use the same worker string format as in the plugin matching
    worker_str = "ObanChore.StatusTest.TestWorker"
    job = %Oban.Job{id: job_id, worker: worker_str, state: "executing"}

    Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:status:#{job_id}")

    # Simulate Oban telemetry event
    # The plugin expects chores in its state to match against.
    chores = [%{module: ObanChore.StatusTest.TestWorker, name: "Test Worker"}]

    metadata = %{
      conf: %{name: Oban},
      job: job
    }

    # Manually call the telemetry handler
    ObanChore.Plugin.handle_telemetry(
      [:oban, :job, :start],
      %{},
      metadata,
      %{
        oban_name: Oban,
        pubsub_server: ObanChore.TestPubSub,
        chores: chores
      }
    )

    assert_receive {:oban_chore_state, ^job_id, :executing}
  end

  test "stop event broadcasts :completed" do
    job = %Oban.Job{id: 1, worker: @worker_str, state: "executing"}
    subscribe_status(job.id)

    emit([:oban, :job, :stop], %{job: job})

    assert_receive {:oban_chore_state, 1, :completed}
  end

  test "exception event broadcasts :retryable when the job can be retried" do
    job = %Oban.Job{id: 2, worker: @worker_str, state: "retryable"}
    subscribe_status(job.id)

    emit([:oban, :job, :exception], %{job: job})

    assert_receive {:oban_chore_state, 2, :retryable}
  end

  test "exception event broadcasts :discarded when the job was discarded" do
    job = %Oban.Job{id: 3, worker: @worker_str, state: "discarded"}
    subscribe_status(job.id)

    emit([:oban, :job, :exception], %{job: job})

    assert_receive {:oban_chore_state, 3, :discarded}
  end

  test "insert event with multiple jobs broadcasts each job's own state" do
    jobs = [
      %Oban.Job{id: 10, worker: @worker_str, state: "available"},
      %Oban.Job{id: 11, worker: @worker_str, state: "scheduled"}
    ]

    Enum.each(jobs, &subscribe_status(&1.id))

    emit([:oban, :job, :insert, :stop], %{jobs: jobs})

    assert_receive {:oban_chore_state, 10, :available}
    assert_receive {:oban_chore_state, 11, :scheduled}
  end

  test "matches workers stored with the Elixir. prefix" do
    job = %Oban.Job{id: 20, worker: "Elixir." <> @worker_str, state: "executing"}
    subscribe_status(job.id)

    emit([:oban, :job, :start], %{job: job})

    assert_receive {:oban_chore_state, 20, :executing}
  end

  test "ignores jobs whose worker is not a known chore" do
    job = %Oban.Job{id: 30, worker: "Some.OtherWorker", state: "executing"}
    subscribe_status(job.id)

    emit([:oban, :job, :start], %{job: job})

    refute_receive {:oban_chore_state, 30, _}
  end

  test "ignores events from a different Oban instance" do
    job = %Oban.Job{id: 40, worker: @worker_str, state: "executing"}
    subscribe_status(job.id)

    emit([:oban, :job, :start], %{job: job}, OtherOban)

    refute_receive {:oban_chore_state, 40, _}
  end

  test "ignores metadata without jobs" do
    Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:counts")

    assert [] == emit([:oban, :job, :start], %{})

    refute_receive {:oban_chore_count, _, _}
  end

  defp subscribe_status(job_id) do
    Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:status:#{job_id}")
  end

  defp emit(event, metadata, oban_name \\ Oban) do
    ObanChore.Plugin.handle_telemetry(
      event,
      %{},
      Map.put(metadata, :conf, %{name: oban_name}),
      %{oban_name: Oban, pubsub_server: ObanChore.TestPubSub, chores: @chores}
    )
  end
end
