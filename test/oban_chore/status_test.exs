defmodule ObanChore.StatusTest do
  use ExUnit.Case, async: false

  alias ObanChore.Test.MockRepo

  @worker "ObanChore.StatusTest.TestWorker"
  @chores [%{module: ObanChore.StatusTest.TestWorker, name: "Test Worker"}]

  setup do
    # Ensure PubSub is configured for the test
    Application.put_env(:oban_chore, :pubsub_server, ObanChore.TestPubSub)

    # Start a dummy PubSub for testing if not already started
    # In a real project, this would be in test_helper.exs or supervised
    start_supervised!({Phoenix.PubSub, name: ObanChore.TestPubSub})

    start_supervised!(
      {Oban, name: Oban, repo: MockRepo, testing: :inline, notifier: Oban.Notifiers.Isolated}
    )

    :ok
  end

  defp emit(event, metadata, oban_name \\ Oban) do
    ObanChore.Plugin.handle_telemetry(
      event,
      %{},
      Map.put(metadata, :conf, %{name: Oban}),
      %{oban_name: oban_name, pubsub_server: ObanChore.TestPubSub, chores: @chores}
    )
  end

  defp subscribe_status(job_id) do
    Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:status:#{job_id}")
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

  test "stopped jobs are broadcast as completed" do
    subscribe_status(1)

    emit([:oban, :job, :stop], %{job: %Oban.Job{id: 1, worker: @worker, state: "executing"}})

    assert_receive {:oban_chore_state, 1, :completed}
  end

  test "failed jobs are broadcast as retryable or discarded" do
    subscribe_status(1)
    subscribe_status(2)

    emit([:oban, :job, :exception], %{job: %Oban.Job{id: 1, worker: @worker, state: "executing"}})
    emit([:oban, :job, :exception], %{job: %Oban.Job{id: 2, worker: @worker, state: "discarded"}})

    assert_receive {:oban_chore_state, 1, :retryable}
    assert_receive {:oban_chore_state, 2, :discarded}
  end

  test "inserted jobs are broadcast with their current state" do
    subscribe_status(1)
    subscribe_status(2)

    jobs = [
      %Oban.Job{id: 1, worker: @worker, state: "available"},
      %Oban.Job{id: 2, worker: @worker, state: "scheduled"}
    ]

    emit([:oban, :job, :insert, :stop], %{jobs: jobs})

    assert_receive {:oban_chore_state, 1, :available}
    assert_receive {:oban_chore_state, 2, :scheduled}
  end

  test "broadcasts the refreshed running count of the chore" do
    MockRepo.stub(:aggregate, 3)
    Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:counts")

    emit([:oban, :job, :start], %{job: %Oban.Job{id: 1, worker: @worker, state: "executing"}})

    assert_receive {:oban_chore_count, ObanChore.StatusTest.TestWorker, 3}
  end

  test "ignores jobs of workers that are not chores" do
    subscribe_status(1)
    Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:counts")

    emit([:oban, :job, :start], %{job: %Oban.Job{id: 1, worker: "MyApp.OtherWorker"}})

    refute_receive {:oban_chore_state, _, _}
    refute_receive {:oban_chore_count, _, _}
  end

  test "ignores events from other Oban instances" do
    subscribe_status(1)

    emit(
      [:oban, :job, :start],
      %{job: %Oban.Job{id: 1, worker: @worker, state: "executing"}},
      ObanChore.OtherOban
    )

    refute_receive {:oban_chore_state, _, _}
  end
end
