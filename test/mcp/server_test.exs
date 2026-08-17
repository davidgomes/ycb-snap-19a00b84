defmodule Tidewave.MCP.ServerTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Tidewave.MCP.Server

  @moduletag :capture_log

  @assigns %{
    allow_remote_access: false,
    phoenix_endpoint: nil,
    inspect_opts: [charlists: :as_lists, limit: 50, pretty: true]
  }

  describe "handle_message/3" do
    test "handles initialization message" do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "initialize",
        "id" => "1",
        "params" => %{
          "protocolVersion" => "2025-03-26",
          "capabilities" => %{
            "version" => "1.0"
          }
        }
      }

      assert {:ok, response} = Server.handle_message(message, @assigns, true)
      assert response.jsonrpc == "2.0"
      assert response.id == "1"
      assert response.result.protocolVersion == "2025-03-26"
      assert is_list(response.result.tools)
      assert "browser_eval" in Enum.map(response.result.tools, & &1.name)
    end

    test "handles initialized notification" do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "notifications/initialized"
      }

      assert Server.handle_message(message, @assigns, true) == {:ok, nil}
    end

    test "handles cancelled notification" do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "notifications/cancelled",
        "params" => %{"reason" => "test"}
      }

      assert Server.handle_message(message, @assigns, true) == {:ok, nil}
    end

    test "ignores unhandled notifications without crashing" do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "notifications/roots/list_changed"
      }

      assert Server.handle_message(message, @assigns, true) == {:ok, nil}
    end

    test "handles tools/list request" do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "tools/list",
        "id" => "2"
      }

      assert {:ok, response} = Server.handle_message(message, @assigns, true)
      assert response.jsonrpc == "2.0"
      assert response.id == "2"
      assert is_list(response.result.tools)
      assert "browser_eval" in Enum.map(response.result.tools, & &1.name)
    end

    test "does not include browser tools when disabled" do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "tools/list",
        "id" => "2"
      }

      assert {:ok, response} = Server.handle_message(message, @assigns, false)
      refute "browser_eval" in Enum.map(response.result.tools, & &1.name)
    end

    test "does not dispatch browser tools when disabled" do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "tools/call",
        "id" => "3",
        "params" => %{"name" => "browser_eval", "arguments" => %{}}
      }

      assert {:error, error} = Server.handle_message(message, @assigns, false)
      assert error.error.code == -32601
    end

    test "returns invalid arguments for malformed browser tool arguments" do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "tools/call",
        "id" => "3",
        "params" => %{"name" => "browser_eval", "arguments" => "invalid"}
      }

      assert {:error, error} = Server.handle_message(message, @assigns, true)
      assert error.error.code == -32602
      assert error.error.message == "Invalid arguments for tool"
    end

    test "handles tool calls" do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "tools/call",
        "id" => "3",
        "params" => %{
          "name" => "project_eval",
          "arguments" => %{"code" => "1 + 1"}
        }
      }

      assert {:ok, response} = Server.handle_message(message, @assigns, true)
      assert response.jsonrpc == "2.0"
      assert response.id == "3"
      assert response.result.content
    end

    test "handles prompts/list request" do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "prompts/list",
        "id" => "4"
      }

      assert {:ok, response} = Server.handle_message(message, @assigns, true)
      assert response.result.prompts == []
    end

    test "handles resources/list request" do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "resources/list",
        "id" => "6"
      }

      assert {:ok, response} = Server.handle_message(message, @assigns, true)
      assert response.result.resources == []
    end

    test "handles resources/templates/list request" do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "resources/templates/list",
        "id" => "10"
      }

      assert {:ok, response} = Server.handle_message(message, @assigns, true)
      assert response.result.templates == []
    end

    test "logs and returns method not found for unsupported methods" do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "unsupported/method",
        "id" => "11"
      }

      log =
        capture_log([level: :warning], fn ->
          assert {:error, error} = Server.handle_message(message, @assigns, true)
          assert error.error.code == -32601
        end)

      assert log =~ "Received unsupported method"
    end
  end

  describe "validate_jsonrpc_message/1" do
    test "accepts a well-formed request" do
      message = %{"jsonrpc" => "2.0", "method" => "ping", "id" => "1"}
      assert Server.validate_jsonrpc_message(message) == {:ok, message}
    end

    test "accepts a well-formed notification" do
      message = %{"jsonrpc" => "2.0", "method" => "notifications/initialized"}
      assert Server.validate_jsonrpc_message(message) == {:ok, message}
    end

    test "rejects an invalid message" do
      assert Server.validate_jsonrpc_message(%{"invalid" => "message"}) ==
               {:error, :invalid_jsonrpc}
    end
  end
end
