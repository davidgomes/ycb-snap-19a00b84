defmodule ObanEvents.DispatchWorkerTest do
  use ExUnit.Case, async: true
  use Oban.Testing, repo: ObanEvents.Test.Repo

  import ExUnit.CaptureLog

  alias ObanEvents.DispatchWorker
  alias ObanEvents.Event

  # Mock handler for testing
  defmodule TestHandler do
    @moduledoc false
    @behaviour ObanEvents.Handler

    alias ObanEvents.Event

    def handle_event(:test_event, %Event{data: %{"action" => "success"}}) do
      send(self(), {:handler_called, :test_event, %{"action" => "success"}})
      :ok
    end

    def handle_event(:test_event, %Event{data: %{"action" => "error"}}) do
      send(self(), {:handler_called, :test_event, %{"action" => "error"}})
      {:error, :test_error}
    end

    def handle_event(:test_event, %Event{data: %{"action" => "raise"}}) do
      raise "Test exception"
    end

    def handle_event(:test_event, %Event{data: %{"action" => "success_with_result"}}) do
      send(self(), {:handler_called, :test_event, %{"action" => "success_with_result"}})
      {:ok, %{processed: true, count: 42}}
    end

    def handle_event(:test_event, %Event{data: %{"action" => "unexpected"}}) do
      send(self(), {:handler_called, :test_event, %{"action" => "unexpected"}})
      :unexpected_return_value
    end

    def handle_event(:test_event, %Event{data: %{"action" => "capture"}} = event) do
      send(self(), {:handler_called, :test_event, event})
      :ok
    end

    def handle_event(_event, _data), do: :ok
  end

  describe "perform/1" do
    test "successfully processes event and calls handler" do
      job_args = %{
        "event" => "test_event",
        "handler" => "Elixir.ObanEvents.DispatchWorkerTest.TestHandler",
        "data" => %{"action" => "success"}
      }

      assert :ok = perform_job(DispatchWorker, job_args)

      assert_received {:handler_called, :test_event, %{"action" => "success"}}
    end

    test "returns error when handler returns error" do
      job_args = %{
        "event" => "test_event",
        "handler" => "Elixir.ObanEvents.DispatchWorkerTest.TestHandler",
        "data" => %{"action" => "error"}
      }

      log =
        capture_log(fn ->
          assert {:error, :test_error} = perform_job(DispatchWorker, job_args)
        end)

      assert log =~ "Event handler failed"
      assert_received {:handler_called, :test_event, %{"action" => "error"}}
    end

    test "handles handler exceptions gracefully" do
      job_args = %{
        "event" => "test_event",
        "handler" => "Elixir.ObanEvents.DispatchWorkerTest.TestHandler",
        "data" => %{"action" => "raise"}
      }

      assert_raise RuntimeError, "Test exception", fn ->
        perform_job(DispatchWorker, job_args)
      end
    end

    test "returns error for invalid job arguments" do
      # Missing event
      job_args = %{
        "handler" => "SomeHandler",
        "data" => %{}
      }

      log =
        capture_log(fn ->
          assert {:error, _} = perform_job(DispatchWorker, job_args)
        end)

      assert log =~ "DispatchWorker received invalid job arguments"
    end

    test "returns error for invalid handler module" do
      job_args = %{
        "event" => "test_event",
        "handler" => "NonExistent.Handler.Module",
        "data" => %{}
      }

      assert_raise ArgumentError, fn ->
        perform_job(DispatchWorker, job_args)
      end
    end

    test "handles {:ok, result} return value" do
      job_args = %{
        "event" => "test_event",
        "handler" => "Elixir.ObanEvents.DispatchWorkerTest.TestHandler",
        "data" => %{"action" => "success_with_result"}
      }

      assert :ok = perform_job(DispatchWorker, job_args)
      assert_received {:handler_called, :test_event, %{"action" => "success_with_result"}}
    end

    test "handles unexpected return value gracefully" do
      job_args = %{
        "event" => "test_event",
        "handler" => "Elixir.ObanEvents.DispatchWorkerTest.TestHandler",
        "data" => %{"action" => "unexpected"}
      }

      log =
        capture_log(fn ->
          assert :ok = perform_job(DispatchWorker, job_args)
        end)

      assert log =~ "Event handler returned unexpected value"
      assert_received {:handler_called, :test_event, %{"action" => "unexpected"}}
    end

    test "passes event metadata to the handler" do
      event_id = Ecto.UUID.generate()
      causation_id = Ecto.UUID.generate()
      correlation_id = Ecto.UUID.generate()

      job_args = %{
        "event" => "test_event",
        "handler" => "Elixir.ObanEvents.DispatchWorkerTest.TestHandler",
        "data" => %{"action" => "capture"},
        "event_id" => event_id,
        "metadata" => %{"actor_id" => 42},
        "emitted_at" => "2025-01-02T03:04:05.123456Z",
        "causation_id" => causation_id,
        "correlation_id" => correlation_id
      }

      assert :ok = perform_job(DispatchWorker, job_args)

      assert_received {:handler_called, :test_event, %Event{} = event}
      assert event.id == event_id
      assert event.name == :test_event
      assert event.data == %{"action" => "capture"}
      assert event.metadata == %{"actor_id" => 42}
      assert event.emitted_at == ~U[2025-01-02 03:04:05.123456Z]
      assert event.causation_id == causation_id
      assert event.correlation_id == correlation_id
    end

    test "processes jobs without event metadata" do
      job_args = %{
        "event" => "test_event",
        "handler" => "Elixir.ObanEvents.DispatchWorkerTest.TestHandler",
        "data" => %{"action" => "capture"}
      }

      assert :ok = perform_job(DispatchWorker, job_args)

      assert_received {:handler_called, :test_event, %Event{} = event}
      assert event.data == %{"action" => "capture"}
      assert event.metadata == %{}
      assert event.id == nil
      assert event.emitted_at == nil
    end
  end

  describe "Oban configuration" do
    test "accepts queue option" do
      changeset =
        DispatchWorker.new(
          %{
            "event" => "test",
            "handler" => "Test",
            "data" => %{}
          },
          queue: :custom_queue
        )

      assert changeset.changes.queue == "custom_queue"
    end

    test "accepts priority option" do
      changeset =
        DispatchWorker.new(
          %{
            "event" => "test",
            "handler" => "Test",
            "data" => %{}
          },
          priority: 0
        )

      assert changeset.changes.priority == 0
    end

    test "accepts max_attempts option" do
      changeset =
        DispatchWorker.new(
          %{
            "event" => "test",
            "handler" => "Test",
            "data" => %{}
          },
          max_attempts: 10
        )

      assert changeset.changes.max_attempts == 10
    end

    test "accepts all options together" do
      changeset =
        DispatchWorker.new(
          %{
            "event" => "test",
            "handler" => "Test",
            "data" => %{}
          },
          queue: :high_priority,
          max_attempts: 5,
          priority: 0
        )

      assert changeset.changes.queue == "high_priority"
      assert changeset.changes.priority == 0
      assert changeset.changes.max_attempts == 5
    end
  end
end
