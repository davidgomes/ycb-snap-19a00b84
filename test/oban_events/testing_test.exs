defmodule ObanEvents.TestingTest do
  use ExUnit.Case, async: true
  use ObanEvents.Testing, repo: ObanEvents.Test.Repo

  import ExUnit.CaptureLog

  alias ObanEvents.Event

  defmodule EchoHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(:fail, _event), do: {:error, :failed}

    def handle_event(event_name, %Event{} = event) do
      send(self(), {:handled, event_name, event})
      :ok
    end
  end

  defmodule TestEventBus do
    @moduledoc false
    use ObanEvents

    @event_handlers %{
      user_created: [ObanEvents.TestingTest.EchoHandler],
      user_deleted: []
    }
  end

  describe "build_event/3" do
    test "normalizes data and metadata to string keys" do
      event =
        build_event(:user_created, %{user_id: 1, profile: %{name: "Ada"}},
          metadata: %{source: :test},
          causation_id: "cause-1"
        )

      assert %Event{event_name: :user_created, causation_id: "cause-1"} = event
      assert event.data == %{"user_id" => 1, "profile" => %{"name" => "Ada"}}
      assert event.metadata == %{"source" => "test"}
      assert event.correlation_id == event.event_id
      assert {:ok, _} = Ecto.UUID.cast(event.event_id)
    end

    test "defaults data to an empty map" do
      assert %Event{data: %{}, metadata: %{}} = build_event(:user_deleted)
    end
  end

  describe "perform_event/4" do
    test "runs the handler through the dispatch worker" do
      log =
        capture_log(fn ->
          assert :ok =
                   perform_event(EchoHandler, :user_created, %{user_id: 1},
                     metadata: %{source: "test"}
                   )
        end)

      assert log =~ "Processing event: user_created"
      assert_received {:handled, :user_created, event}
      assert event.data == %{"user_id" => 1}
      assert event.metadata == %{"source" => "test"}
      assert %DateTime{} = event.emitted_at
    end

    test "returns handler errors" do
      capture_log(fn ->
        assert {:error, :failed} = perform_event(EchoHandler, :fail)
      end)
    end
  end

  describe "to_events/1" do
    test "returns one event per emission" do
      capture_log(fn ->
        {:ok, jobs_one} = TestEventBus.emit(:user_created, %{user_id: 1}, metadata: %{a: 1})
        {:ok, jobs_two} = TestEventBus.emit(:user_created, %{user_id: 2})

        assert [first, second] = ObanEvents.Testing.to_events(jobs_one ++ jobs_one ++ jobs_two)
        assert first.data == %{"user_id" => 1}
        assert first.metadata == %{"a" => 1}
        assert second.data == %{"user_id" => 2}
      end)
    end
  end
end
