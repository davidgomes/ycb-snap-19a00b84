defmodule ObanEvents.EventTest do
  use ExUnit.Case, async: true

  alias ObanEvents.Event

  doctest ObanEvents.Event

  defmodule TestHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(_event, _data), do: :ok
  end

  describe "new/3" do
    test "generates an id and an emit time" do
      event = Event.new(:user_created, %{"user_id" => 1})

      assert is_binary(event.id)
      assert {:ok, _uuid} = Ecto.UUID.cast(event.id)
      assert %DateTime{} = event.emitted_at
      assert event.name == :user_created
      assert event.meta == %{}
      assert event.handler == nil
    end

    test "normalizes atom keys in data and metadata to strings" do
      event =
        Event.new(:user_created, %{user_id: 1, address: %{city: "Berlin"}, tags: [%{name: "a"}]},
          meta: %{actor_id: 7}
        )

      assert event.data == %{
               "user_id" => 1,
               "address" => %{"city" => "Berlin"},
               "tags" => [%{"name" => "a"}]
             }

      assert event.meta == %{"actor_id" => 7}
    end

    test "leaves structs in the payload untouched" do
      emitted_at = ~U[2026-01-01 00:00:00Z]
      event = Event.new(:user_created, %{inserted_at: emitted_at})

      assert event.data == %{"inserted_at" => emitted_at}
    end

    test "accepts explicit metadata" do
      emitted_at = ~U[2026-01-01 00:00:00Z]

      event =
        Event.new(:user_created, %{},
          id: "event-1",
          emitted_at: emitted_at,
          meta: %{"actor_id" => 7},
          handler: TestHandler,
          job_id: 42,
          attempt: 2,
          max_attempts: 5
        )

      assert event.id == "event-1"
      assert event.emitted_at == emitted_at
      assert event.meta == %{"actor_id" => 7}
      assert event.handler == TestHandler
      assert event.job_id == 42
      assert event.attempt == 2
      assert event.max_attempts == 5
    end

    test "ignores unknown options" do
      assert %Event{} = Event.new(:user_created, %{}, queue: :other)
    end

    test "raises when metadata is not a map" do
      assert_raise ArgumentError, ~r/:meta must be a map/, fn ->
        Event.new(:user_created, %{}, meta: "nope")
      end
    end

    test "raises when the id is not a string" do
      assert_raise ArgumentError, ~r/:id must be a string/, fn ->
        Event.new(:user_created, %{}, id: 1)
      end
    end

    test "raises when the emit time is not a DateTime" do
      assert_raise ArgumentError, ~r/:emitted_at must be a DateTime/, fn ->
        Event.new(:user_created, %{}, emitted_at: ~N[2026-01-01 00:00:00])
      end
    end
  end

  describe "to_args/1" do
    test "includes the payload and the metadata" do
      emitted_at = ~U[2026-01-01 00:00:00Z]

      args =
        :user_created
        |> Event.new(%{user_id: 1}, id: "event-1", emitted_at: emitted_at, meta: %{actor_id: 7})
        |> Event.for_handler(TestHandler)
        |> Event.to_args()

      assert args == %{
               "event" => "user_created",
               "handler" => "Elixir.ObanEvents.EventTest.TestHandler",
               "data" => %{"user_id" => 1},
               "meta" => %{"actor_id" => 7},
               "event_id" => "event-1",
               "emitted_at" => "2026-01-01T00:00:00Z"
             }
    end

    test "raises without a handler" do
      assert_raise ArgumentError, ~r/without a :handler/, fn ->
        :user_created |> Event.new(%{}) |> Event.to_args()
      end
    end
  end

  describe "from_job/1" do
    test "round trips an event through job args" do
      event =
        :user_created
        |> Event.new(%{user_id: 1}, meta: %{actor_id: 7})
        |> Event.for_handler(TestHandler)

      job = %Oban.Job{id: 42, attempt: 2, max_attempts: 5, args: Event.to_args(event)}

      assert {:ok, rebuilt} = Event.from_job(job)
      assert rebuilt.id == event.id
      assert rebuilt.name == :user_created
      assert rebuilt.handler == TestHandler
      assert rebuilt.data == %{"user_id" => 1}
      assert rebuilt.meta == %{"actor_id" => 7}
      assert DateTime.compare(rebuilt.emitted_at, event.emitted_at) == :eq
      assert rebuilt.job_id == 42
      assert rebuilt.attempt == 2
      assert rebuilt.max_attempts == 5
    end

    test "falls back to job values for jobs enqueued without metadata" do
      inserted_at = ~U[2026-01-01 00:00:00Z]

      job = %Oban.Job{
        id: 42,
        inserted_at: inserted_at,
        args: %{
          "event" => "user_created",
          "handler" => "Elixir.ObanEvents.EventTest.TestHandler",
          "data" => %{"user_id" => 1}
        }
      }

      assert {:ok, event} = Event.from_job(job)
      assert event.id == nil
      assert event.meta == %{}
      assert event.emitted_at == inserted_at
    end

    test "returns :error when the args don't describe an event" do
      assert :error = Event.from_job(%Oban.Job{args: %{"handler" => "Some", "data" => %{}}})
      assert :error = Event.from_job(%Oban.Job{args: %{}})
    end

    test "raises for unknown handler modules" do
      job = %Oban.Job{
        args: %{
          "event" => "user_created",
          "handler" => "Elixir.NonExistent.Handler",
          "data" => %{}
        }
      }

      assert_raise ArgumentError, fn -> Event.from_job(job) end
    end
  end

  describe "normalize_payload/1" do
    test "converts map keys to strings recursively" do
      assert Event.normalize_payload(%{a: %{b: [1, %{c: 2}]}}) == %{
               "a" => %{"b" => [1, %{"c" => 2}]}
             }
    end

    test "passes through values that aren't maps" do
      assert Event.normalize_payload("string") == "string"
      assert Event.normalize_payload(1) == 1
    end
  end
end
