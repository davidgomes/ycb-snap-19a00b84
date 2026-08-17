defmodule ObanEvents.TestingTest do
  use ExUnit.Case, async: true

  import ObanEvents.Testing

  defmodule TestHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(_event, _data), do: :ok
  end

  # `assert_event_emitted/2,3` wraps `Oban.Testing.assert_enqueued/1`, which
  # queries the configured Ecto repo directly. That requires a live database
  # and an Oban instance running in `:manual` (rather than `:inline`) testing
  # mode, neither of which this library's own test suite provisions. Coverage
  # here focuses on `event_args/3`, the pure helper the macro builds on; see
  # the moduledoc and README for `assert_event_emitted/2,3` usage in a
  # consuming application with a real repo.
  describe "event_args/3" do
    test "builds job args matching what emit/2 enqueues" do
      args = event_args(:widget_created, TestHandler, %{"widget_id" => 1})

      assert args == %{
               "event" => "widget_created",
               "handler" => "Elixir.ObanEvents.TestingTest.TestHandler",
               "data" => %{"widget_id" => 1}
             }
    end

    test "defaults data to an empty map" do
      assert event_args(:widget_created, TestHandler) == %{
               "event" => "widget_created",
               "handler" => "Elixir.ObanEvents.TestingTest.TestHandler",
               "data" => %{}
             }
    end
  end
end
