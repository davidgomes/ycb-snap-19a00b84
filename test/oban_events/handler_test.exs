defmodule ObanEvents.HandlerTest do
  use ExUnit.Case, async: true

  describe "use ObanEvents.Handler" do
    test "compiles handlers that define handle_event/2" do
      assert Code.compile_string("""
             defmodule ObanEventsHandlerArityTwo do
               use ObanEvents.Handler

               @impl true
               def handle_event(_event, _data), do: :ok
             end
             """)
    end

    test "compiles handlers that define handle_event/3" do
      assert Code.compile_string("""
             defmodule ObanEventsHandlerArityThree do
               use ObanEvents.Handler

               @impl true
               def handle_event(_event, _data, _meta), do: :ok
             end
             """)
    end

    test "raises when no handle_event callback is defined" do
      assert_raise CompileError, ~r/Missing handle_event callback/, fn ->
        Code.compile_string("""
        defmodule ObanEventsHandlerWithoutCallback do
          use ObanEvents.Handler
        end
        """)
      end
    end
  end
end
