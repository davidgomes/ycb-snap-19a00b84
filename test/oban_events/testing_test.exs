defmodule ObanEvents.TestingTest do
  use ExUnit.Case, async: true

  use Oban.Testing, repo: ObanEvents.Test.Repo
  import ObanEvents.Testing

  defmodule TestHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(_event, _data), do: :ok
  end

  defmodule TestEventBus do
    @moduledoc false
    use ObanEvents

    @event_handlers %{
      widget_created: [ObanEvents.TestingTest.TestHandler],
      widget_deleted: []
    }
  end

  describe "assert_event_emitted/3" do
    test "matches on event name alone" do
      {:ok, _jobs} = TestEventBus.emit(:widget_created, %{"widget_id" => 1})

      assert_event_emitted(:widget_created)
    end

    test "matches on event name and data" do
      {:ok, _jobs} = TestEventBus.emit(:widget_created, %{"widget_id" => 42})

      assert_event_emitted(:widget_created, %{"widget_id" => 42})
    end

    test "matches on event name, data, and handler" do
      {:ok, _jobs} = TestEventBus.emit(:widget_created, %{"widget_id" => 7})

      assert_event_emitted(:widget_created, %{"widget_id" => 7}, handler: TestHandler)
    end
  end

  describe "refute_event_emitted/3" do
    test "passes when no matching job was enqueued" do
      {:ok, _jobs} = TestEventBus.emit(:widget_created, %{"widget_id" => 1})

      refute_event_emitted(:widget_deleted)
    end
  end

  describe "event_args/3" do
    test "builds args usable with Oban.Testing matchers" do
      {:ok, _jobs} = TestEventBus.emit(:widget_created, %{"widget_id" => 99})

      assert_enqueued(
        worker: ObanEvents.DispatchWorker,
        args: event_args(:widget_created, %{"widget_id" => 99})
      )
    end
  end
end
