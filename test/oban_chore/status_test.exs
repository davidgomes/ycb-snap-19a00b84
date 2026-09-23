defmodule ObanChore.StatusTest do
  use ObanChore.DataCase, async: false

  test "telemetry broadcasts job state changes" do
    job_id = 456
    # Use the same worker string format as in the plugin matching
    worker_str = "ObanChore.StatusTest.TestWorker"
    job = %Oban.Job{id: job_id, worker: worker_str, state: "executing"}

    Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:status:#{job_id}")
    Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:counts")

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
    assert_receive {:oban_chore_count, ObanChore.StatusTest.TestWorker, 0}
  end

  test "telemetry ignores events from other Oban instances" do
    job = %Oban.Job{id: 789, worker: "ObanChore.StatusTest.TestWorker", state: "executing"}

    Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:status:789")

    ObanChore.Plugin.handle_telemetry(
      [:oban, :job, :start],
      %{},
      %{conf: %{name: OtherOban}, job: job},
      %{
        oban_name: Oban,
        pubsub_server: ObanChore.TestPubSub,
        chores: [%{module: ObanChore.StatusTest.TestWorker, name: "Test Worker"}]
      }
    )

    refute_receive {:oban_chore_state, 789, _}
  end

  test "telemetry ignores jobs for workers that aren't chores" do
    job = %Oban.Job{id: 790, worker: "Some.OtherWorker", state: "executing"}

    Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:status:790")

    ObanChore.Plugin.handle_telemetry(
      [:oban, :job, :start],
      %{},
      %{conf: %{name: Oban}, job: job},
      %{
        oban_name: Oban,
        pubsub_server: ObanChore.TestPubSub,
        chores: [%{module: ObanChore.StatusTest.TestWorker, name: "Test Worker"}]
      }
    )

    refute_receive {:oban_chore_state, 790, _}
  end
end
