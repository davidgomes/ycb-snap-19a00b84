defmodule ObanEvents.TestingTest do
  use ExUnit.Case, async: true
  use ObanEvents.Testing, repo: ObanEvents.Test.Repo

  alias ObanEvents.Event

  doctest ObanEvents.Testing

  defmodule TestHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(:user_created, %Event{data: %{"fail" => true}}), do: {:error, :failed}

    def handle_event(event_name, event) do
      send(self(), {:handled, event_name, event})
      :ok
    end
  end

  describe "build_event/3" do
    test "builds an event with defaults" do
      event = build_event(:user_created)

      assert %Event{name: :user_created, data: %{}, metadata: %{}, attempt: 1} = event
      assert {:ok, _} = Ecto.UUID.cast(event.id)
      assert %DateTime{} = event.emitted_at
      assert is_integer(event.job_id)
    end

    test "normalizes data and metadata to string keys" do
      event =
        build_event(:user_created, %{user_id: 1, profile: %{name: "Ada"}},
          metadata: %{actor_id: 2}
        )

      assert event.data == %{"user_id" => 1, "profile" => %{"name" => "Ada"}}
      assert event.metadata == %{"actor_id" => 2}
    end

    test "accepts overrides" do
      event =
        build_event(:user_created, %{},
          event_id: "event-1",
          emitted_at: ~U[2026-01-01 00:00:00Z],
          job_id: 99,
          attempt: 3
        )

      assert event.id == "event-1"
      assert event.emitted_at == ~U[2026-01-01 00:00:00Z]
      assert event.job_id == 99
      assert event.attempt == 3
    end

    test "raises when metadata is not a map" do
      assert_raise ArgumentError, ~r/expected :metadata to be a map/, fn ->
        build_event(:user_created, %{}, metadata: "nope")
      end
    end
  end

  describe "perform_event/4" do
    test "runs the handler through the dispatch worker" do
      assert :ok = perform_event(TestHandler, :user_created, %{user_id: 1})

      assert_received {:handled, :user_created, %Event{} = event}
      assert event.data == %{"user_id" => 1}
      assert event.metadata == %{}
      assert {:ok, _} = Ecto.UUID.cast(event.id)
    end

    test "passes event and job options" do
      assert :ok =
               perform_event(TestHandler, :user_created, %{},
                 metadata: %{actor_id: 2},
                 event_id: "event-1",
                 emitted_at: ~U[2026-01-01 00:00:00.000000Z],
                 attempt: 4
               )

      assert_received {:handled, :user_created, event}
      assert event.metadata == %{"actor_id" => 2}
      assert event.id == "event-1"
      assert event.emitted_at == ~U[2026-01-01 00:00:00.000000Z]
      assert event.attempt == 4
    end

    test "returns handler errors" do
      ExUnit.CaptureLog.capture_log(fn ->
        assert {:error, :failed} = perform_event(TestHandler, :user_created, %{fail: true})
      end)
    end
  end

  describe "__using__/1" do
    test "requires a :repo option" do
      assert_raise ArgumentError, ~r/requires a :repo option/, fn ->
        Code.compile_string("""
        defmodule ObanEvents.TestingTest.MissingRepo do
          use ObanEvents.Testing
        end
        """)
      end
    end
  end
end
