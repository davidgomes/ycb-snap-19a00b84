defmodule ObanChore.StatusTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias ObanChore.Test.MockRepo

  @moduletag :capture_log

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

  describe "job state broadcasts" do
    test "a stopped job is reported as completed" do
      job = job(1, "executing")
      subscribe_status(job)

      emit([:oban, :job, :stop], %{job: job})

      assert_receive {:oban_chore_state, 1, :completed}
    end

    test "a failed job with attempts left is reported as retryable" do
      job = job(2, "executing")
      subscribe_status(job)

      emit([:oban, :job, :exception], %{job: job})

      assert_receive {:oban_chore_state, 2, :retryable}
    end

    test "a failed job that was discarded is reported as discarded" do
      job = job(3, "discarded")
      subscribe_status(job)

      emit([:oban, :job, :exception], %{job: job})

      assert_receive {:oban_chore_state, 3, :discarded}
    end

    test "other events report the job's own state for every chore job" do
      available = job(4, "available")
      scheduled = job(5, "scheduled")
      unrelated = %Oban.Job{id: 6, worker: "SomeOtherWorker", state: "available"}
      Enum.each([available, scheduled, unrelated], &subscribe_status/1)

      emit([:oban, :job, :insert, :stop], %{jobs: [available, scheduled, unrelated]})

      assert_receive {:oban_chore_state, 4, :available}
      assert_receive {:oban_chore_state, 5, :scheduled}
      refute_receive {:oban_chore_state, 6, _}
    end

    test "jobs from workers that aren't chores are ignored" do
      job = %Oban.Job{id: 7, worker: "SomeOtherWorker", state: "executing"}
      subscribe_status(job)
      Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:counts")

      emit([:oban, :job, :start], %{job: job})

      refute_receive {:oban_chore_state, 7, _}
      refute_receive {:oban_chore_count, _, _}
    end

    test "events from a different Oban instance are ignored" do
      job = job(8, "executing")
      subscribe_status(job)

      emit([:oban, :job, :start], %{job: job}, conf_name: SomeOtherOban)

      refute_receive {:oban_chore_state, 8, _}
    end
  end

  describe "chore count broadcasts" do
    @oban ObanChore.StatusTest.Oban

    setup do
      start_supervised!(
        {Oban, name: @oban, repo: MockRepo, testing: :manual, notifier: Oban.Notifiers.Isolated}
      )

      Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:counts")

      :ok
    end

    test "broadcasts the number of active jobs for the chore" do
      MockRepo.stub(:aggregate, 2)

      emit([:oban, :job, :start], %{job: job(9, "executing")}, oban_name: @oban)

      assert_receive {:oban_chore_count, ObanChore.StatusTest.TestWorker, 2}
      assert_receive {:repo_aggregate, query}
      assert inspect(query) =~ "j0.worker == ^\"ObanChore.StatusTest.TestWorker\""
    end

    test "broadcasts once per chore when several of its jobs change together" do
      MockRepo.stub(:aggregate, 2)
      jobs = [job(10, "available"), job(11, "available")]

      emit([:oban, :job, :insert, :stop], %{jobs: jobs}, oban_name: @oban)

      assert_receive {:oban_chore_count, ObanChore.StatusTest.TestWorker, 2}
      refute_receive {:oban_chore_count, _, _}
    end
  end

  test "logs an error instead of crashing when the count can't be computed" do
    job = job(12, "executing")
    subscribe_status(job)

    log =
      capture_log(fn ->
        emit([:oban, :job, :start], %{job: job}, oban_name: ObanChore.StatusTest.MissingOban)
      end)

    assert log =~ "[ObanChore] Failed to broadcast chore count for"
    assert_receive {:oban_chore_state, 12, :executing}
  end

  defp job(id, state) do
    %Oban.Job{id: id, worker: "ObanChore.StatusTest.TestWorker", state: state}
  end

  defp subscribe_status(job) do
    Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:status:#{job.id}")
  end

  defp emit(event, metadata, opts \\ []) do
    oban_name = Keyword.get(opts, :oban_name, Oban)
    conf_name = Keyword.get(opts, :conf_name, oban_name)

    ObanChore.Plugin.handle_telemetry(event, %{}, Map.put(metadata, :conf, %{name: conf_name}), %{
      oban_name: oban_name,
      pubsub_server: ObanChore.TestPubSub,
      chores: [%{module: ObanChore.StatusTest.TestWorker, name: "Test Worker"}]
    })
  end
end
