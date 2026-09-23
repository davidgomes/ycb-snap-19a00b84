defmodule ObanChore.StatusTest do
  use ExUnit.Case, async: false

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

  @worker_str "ObanChore.StatusTest.TestWorker"
  @chores [%{module: ObanChore.StatusTest.TestWorker, name: "Test Worker"}]

  defp emit(event, metadata, oban_name \\ Oban) do
    ObanChore.Plugin.handle_telemetry(event, %{}, Map.put_new(metadata, :conf, %{name: Oban}), %{
      oban_name: oban_name,
      pubsub_server: ObanChore.TestPubSub,
      chores: @chores
    })
  end

  test "stop event broadcasts :completed" do
    job = %Oban.Job{id: 1, worker: @worker_str, state: "completed"}
    Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:status:1")
    emit([:oban, :job, :stop], %{job: job})
    assert_receive {:oban_chore_state, 1, :completed}
  end

  test "exception event broadcasts :retryable or :discarded" do
    Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:status:2")
    Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:status:3")

    emit([:oban, :job, :exception], %{job: %Oban.Job{id: 2, worker: @worker_str, state: "retryable"}})
    emit([:oban, :job, :exception], %{job: %Oban.Job{id: 3, worker: @worker_str, state: "discarded"}})

    assert_receive {:oban_chore_state, 2, :retryable}
    assert_receive {:oban_chore_state, 3, :discarded}
  end

  test "insert event broadcasts job state for each job" do
    jobs = [
      %Oban.Job{id: 4, worker: @worker_str, state: "available"},
      %Oban.Job{id: 5, worker: @worker_str, state: "scheduled"}
    ]

    Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:status:4")
    Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:status:5")
    emit([:oban, :job, :insert, :stop], %{jobs: jobs})

    assert_receive {:oban_chore_state, 4, :available}
    assert_receive {:oban_chore_state, 5, :scheduled}
  end

  test "ignores events from other Oban instances" do
    job = %Oban.Job{id: 6, worker: @worker_str, state: "executing"}
    Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:status:6")
    emit([:oban, :job, :start], %{job: job}, OtherOban)
    refute_receive {:oban_chore_state, 6, _}
  end

  test "ignores jobs for workers that are not chores" do
    job = %Oban.Job{id: 7, worker: "Some.Other.Worker", state: "executing"}
    Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:status:7")
    emit([:oban, :job, :start], %{job: job})
    refute_receive {:oban_chore_state, 7, _}
  end
end
