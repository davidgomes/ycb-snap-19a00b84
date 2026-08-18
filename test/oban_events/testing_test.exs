defmodule ObanEvents.TestingTest do
  use ExUnit.Case, async: true
  use ObanEvents.Testing, repo: ObanEvents.Test.Repo

  alias ObanEvents.Event

  defmodule MetadataHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(_name, %{"action" => "error"}, %Event{}), do: {:error, :nope}

    def handle_event(name, data, %Event{} = event) do
      send(self(), {:handled, name, data, event})
      :ok
    end
  end

  defmodule PayloadHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(name, data) do
      send(self(), {:handled, name, data})
      :ok
    end
  end

  # Stands in for the Oban.Testing assertions, which need a database.
  defmodule StubbedOban do
    @moduledoc false
    import ObanEvents.Testing

    def assert_event(name, opts), do: assert_event_emitted(name, opts)
    def refute_event(name, opts), do: refute_event_emitted(name, opts)
    def events(opts \\ []), do: emitted_events(opts)

    defp assert_enqueued(opts), do: send(self(), {:assert_enqueued, opts})
    defp refute_enqueued(opts), do: send(self(), {:refute_enqueued, opts})

    defp all_enqueued(opts) do
      send(self(), {:all_enqueued, opts})

      args =
        ObanEvents.Testing.event_job_args(
          ObanEvents.TestingTest.PayloadHandler,
          :user_created,
          %{user_id: 1},
          meta: %{actor_id: 7}
        )

      [%Oban.Job{id: 1, args: args}, %Oban.Job{id: 2, args: %{"unrelated" => true}}]
    end
  end

  describe "build_event/3" do
    test "builds the event struct a handler receives" do
      event = build_event(:user_created, %{user_id: 1}, meta: %{actor_id: 7})

      assert %Event{name: :user_created} = event
      assert event.data == %{"user_id" => 1}
      assert event.meta == %{"actor_id" => 7}
      assert is_binary(event.id)
    end

    test "accepts pinned metadata" do
      emitted_at = ~U[2026-01-01 00:00:00Z]
      event = build_event(:user_created, %{}, id: "event-1", emitted_at: emitted_at)

      assert event.id == "event-1"
      assert event.emitted_at == emitted_at
    end
  end

  describe "event_args/2" do
    test "only includes the given fields" do
      assert event_args(:user_created) == %{"event" => "user_created"}

      assert event_args(:user_created, data: %{user_id: 1}) == %{
               "event" => "user_created",
               "data" => %{"user_id" => 1}
             }

      assert event_args(:user_created, handler: PayloadHandler, meta: %{actor_id: 7}, id: "e-1") ==
               %{
                 "event" => "user_created",
                 "handler" => "Elixir.ObanEvents.TestingTest.PayloadHandler",
                 "meta" => %{"actor_id" => 7},
                 "event_id" => "e-1"
               }
    end

    test "raises for unknown options" do
      assert_raise ArgumentError, ~r/unknown event option :queue/, fn ->
        event_args(:user_created, queue: :events)
      end
    end
  end

  describe "event_job_args/4" do
    test "includes the generated metadata" do
      args = event_job_args(PayloadHandler, :user_created, %{user_id: 1}, meta: %{actor_id: 7})

      assert args["event"] == "user_created"
      assert args["handler"] == "Elixir.ObanEvents.TestingTest.PayloadHandler"
      assert args["data"] == %{"user_id" => 1}
      assert args["meta"] == %{"actor_id" => 7}
      assert is_binary(args["event_id"])
      assert {:ok, _datetime, _offset} = DateTime.from_iso8601(args["emitted_at"])
    end
  end

  describe "assert_event_emitted/2 and refute_event_emitted/2" do
    test "assert against the dispatch worker jobs" do
      StubbedOban.assert_event(:user_created, handler: PayloadHandler)

      assert_received {:assert_enqueued, opts}

      assert opts[:worker] == ObanEvents.DispatchWorker

      assert opts[:args] == %{
               "event" => "user_created",
               "handler" => "Elixir.ObanEvents.TestingTest.PayloadHandler"
             }
    end

    test "refute against the dispatch worker jobs" do
      StubbedOban.refute_event(:user_deleted, [])

      assert_received {:refute_enqueued, opts}

      assert opts[:worker] == ObanEvents.DispatchWorker
      assert opts[:args] == %{"event" => "user_deleted"}
    end
  end

  describe "emitted_events/1" do
    test "returns the emitted events as structs and skips other jobs" do
      assert [%Event{} = event] = StubbedOban.events(queue: :events)

      assert_received {:all_enqueued, opts}
      assert opts[:worker] == ObanEvents.DispatchWorker
      assert opts[:queue] == :events

      assert event.name == :user_created
      assert event.handler == PayloadHandler
      assert event.data == %{"user_id" => 1}
      assert event.meta == %{"actor_id" => 7}
    end
  end

  describe "perform_event/4" do
    test "runs a handler with the event metadata" do
      assert :ok =
               perform_event(MetadataHandler, :user_created, %{user_id: 1},
                 meta: %{actor_id: 7},
                 id: "event-1"
               )

      assert_received {:handled, :user_created, %{"user_id" => 1}, %Event{} = event}

      assert event.id == "event-1"
      assert event.name == :user_created
      assert event.handler == MetadataHandler
      assert event.meta == %{"actor_id" => 7}
      assert event.attempt == 1
    end

    test "runs handlers that don't take metadata" do
      assert :ok = perform_event(PayloadHandler, :user_created, %{user_id: 1})

      assert_received {:handled, :user_created, %{"user_id" => 1}}
    end

    test "forwards job options" do
      assert :ok = perform_event(MetadataHandler, :user_created, %{}, attempt: 3, max_attempts: 5)

      assert_received {:handled, :user_created, %{}, %Event{attempt: 3, max_attempts: 5}}
    end

    test "returns the handler error" do
      assert {:error, :nope} = perform_event(MetadataHandler, :user_created, %{action: "error"})
    end
  end
end
