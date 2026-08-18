defmodule ObanEvents.TestingTest do
  use ExUnit.Case, async: true
  use Oban.Testing, repo: ObanEvents.Test.Repo
  use ObanEvents.Testing

  defmodule HandlerTwoArity do
    @moduledoc false
    use ObanEvents.Handler

    def handle_event(:test_event, %{"value" => v}), do: {:ok, v}
    def handle_event(_event, _data), do: :ok
  end

  defmodule HandlerThreeArity do
    @moduledoc false
    use ObanEvents.Handler

    def handle_event(:test_event, %{"value" => v}, %{"meta" => m}), do: {:ok, {v, m}}
    def handle_event(_event, _data), do: :ok
  end

  describe "perform_handler/4" do
    test "executes 2-arity handler" do
      assert {:ok, 123} =
               perform_handler(HandlerTwoArity, :test_event, %{"value" => 123})
    end

    test "executes 3-arity handler" do
      assert {:ok, {123, "info"}} =
               perform_handler(HandlerThreeArity, :test_event, %{"value" => 123}, %{
                 "meta" => "info"
               })
    end
  end

  describe "assert_event_enqueued and refute_event_enqueued" do
    test "checks enqueued events with Oban" do
      refute_event_enqueued(:test_event)

      Oban.insert!(
        ObanEvents.DispatchWorker.new(%{
          event: "test_event",
          handler: "Elixir.ObanEvents.TestingTest.HandlerTwoArity",
          data: %{"id" => 1},
          metadata: %{"user_id" => 42}
        })
      )

      assert_event_enqueued(:test_event)
      assert_event_enqueued(:test_event, handler: HandlerTwoArity)
      assert_event_enqueued(:test_event, data: %{"id" => 1})
      assert_event_enqueued(:test_event, metadata: %{"user_id" => 42})
      refute_event_enqueued(:other_event)
    end
  end
end
