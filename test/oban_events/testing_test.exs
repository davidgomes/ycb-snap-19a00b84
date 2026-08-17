defmodule ObanEvents.TestingTest do
  use ExUnit.Case, async: true
  use Oban.Testing, repo: ObanEvents.Test.Repo

  import ObanEvents.Testing

  alias ObanEvents.DispatchWorker

  defmodule TestHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(_event, _data), do: :ok
  end

  defmodule TestEventBus do
    @moduledoc false
    use ObanEvents

    alias ObanEvents.TestingTest.TestHandler

    @event_handlers %{
      user_created: [TestHandler],
      user_updated: []
    }
  end

  describe "event_job_args/3" do
    test "builds job args without a metadata key" do
      args = event_job_args(:user_created, TestHandler, %{"user_id" => 1})

      assert args == %{
               "event" => "user_created",
               "handler" => "Elixir.ObanEvents.TestingTest.TestHandler",
               "data" => %{"user_id" => 1}
             }
    end

    test "defaults data to an empty map" do
      args = event_job_args(:user_created, TestHandler)

      assert args["data"] == %{}
    end
  end

  describe "assert_event_emitted/4" do
    test "finds a matching job while ignoring dynamic metadata" do
      # ObanEvents.emit/2 returns the jobs it created, which in this
      # library's inline testing mode are already executed. This mirrors
      # what `Oban.Testing.all_enqueued/1` would return under `:manual` mode
      # in a consuming application.
      {:ok, jobs} = TestEventBus.emit(:user_created, %{"user_id" => 1})

      job = assert_event_emitted(jobs, :user_created, TestHandler, %{"user_id" => 1})

      assert job.args["event"] == "user_created"
      assert is_binary(job.args["metadata"]["event_id"])
    end

    test "raises when no matching job is found" do
      {:ok, jobs} = TestEventBus.emit(:user_created, %{"user_id" => 1})

      assert_raise ExUnit.AssertionError, fn ->
        assert_event_emitted(jobs, :user_created, TestHandler, %{"user_id" => 999})
      end
    end
  end

  describe "build_event/3" do
    test "returns a deterministic event fixture" do
      event = build_event(:user_created, %{"user_id" => 1})

      assert event.id == "00000000-0000-0000-0000-000000000000"
      assert event.emitted_at == ~U[2024-01-01 00:00:00Z]
      assert event.data == %{"user_id" => 1}
    end

    test "allows overriding id, emitted_at, and metadata" do
      event =
        build_event(:user_created, %{},
          id: "custom-id",
          emitted_at: ~U[2020-01-01 00:00:00Z],
          metadata: %{source: "test"}
        )

      assert event.id == "custom-id"
      assert event.emitted_at == ~U[2020-01-01 00:00:00Z]
      assert event.metadata == %{source: "test"}
    end
  end

  describe "event_perform_args/4" do
    test "builds deterministic job args suitable for perform_job/2" do
      args = event_perform_args(:user_created, TestHandler, %{"user_id" => 1})

      assert :ok = perform_job(DispatchWorker, args)
      assert args["metadata"]["event_id"] == "00000000-0000-0000-0000-000000000000"
    end
  end
end
