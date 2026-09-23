defmodule Tidewave.MCP.HandlerTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Tidewave.MCP.Handler

  @moduletag :capture_log

  @assigns %{phoenix_endpoint: nil, inspect_opts: [charlists: :as_lists, limit: 50, pretty: true]}

  describe "handle_message/3" do
    test "replies to requests" do
      message = %{"jsonrpc" => "2.0", "method" => "ping", "id" => 1}

      assert {:reply, %{jsonrpc: "2.0", id: 1, result: %{}}} =
               Handler.handle_message(message, @assigns)
    end

    test "returns :notification for notifications" do
      message = %{"jsonrpc" => "2.0", "method" => "notifications/initialized"}
      assert Handler.handle_message(message, @assigns) == :notification

      message = %{"jsonrpc" => "2.0", "method" => "notifications/roots/list_changed"}
      assert Handler.handle_message(message, @assigns) == :notification
    end

    test "calls tools with the given assigns" do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "tools/call",
        "id" => "1",
        "params" => %{"name" => "project_eval", "arguments" => %{"code" => "1 + 1"}}
      }

      assert {:reply, %{id: "1", result: %{content: [%{type: "text", text: "2"}]}}} =
               Handler.handle_message(message, @assigns)
    end

    test "includes browser tools by default" do
      message = %{"jsonrpc" => "2.0", "method" => "tools/list", "id" => "1"}

      assert {:reply, %{result: %{tools: tools}}} = Handler.handle_message(message, @assigns)
      assert "browser_eval" in Enum.map(tools, & &1.name)

      assert {:reply, %{result: %{tools: tools}}} =
               Handler.handle_message(message, @assigns, include_browser_tools: false)

      refute "browser_eval" in Enum.map(tools, & &1.name)
    end

    test "returns errors for unknown methods" do
      message = %{"jsonrpc" => "2.0", "method" => "unknown", "id" => "1"}

      assert {:error, %{id: "1", error: %{code: -32601}}} =
               Handler.handle_message(message, @assigns)
    end

    test "replies with an error to invalid JSON-RPC messages" do
      log =
        capture_log([level: :warning], fn ->
          assert {:reply, %{id: nil, error: %{code: -32600, message: "Could not parse message"}}} =
                   Handler.handle_message(%{"invalid" => "message"}, @assigns)
        end)

      assert log =~ "Invalid JSON-RPC message format"
    end
  end

  test "tools have valid callbacks" do
    {_, dispatch_map} = Handler.tools_and_dispatch(true)

    for {tool, callback} <- dispatch_map do
      assert is_function(callback, 1) or is_function(callback, 2),
             "#{tool} does not have a valid callback #{inspect(callback)}"
    end
  end
end
