defmodule Tidewave.MCP.ServerTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  @moduletag :capture_log

  describe "handle_message/3" do
    setup do
      %{config: tidewave_config(), include_browser_tools?: true}
    end

    test "handles initialization message", %{config: config, include_browser_tools?: include?} do
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

      assert {:ok, response} = Tidewave.MCP.Server.handle_message(message, config, include?)

      assert response["jsonrpc"] == "2.0"
      assert response["id"] == "1"
      assert response["result"]["protocolVersion"] == "2025-03-26"
      assert is_list(response["result"]["tools"])
      assert "browser_eval" in Enum.map(response["result"]["tools"], & &1["name"])
    end

    test "handles initialized notification", %{config: config, include_browser_tools?: include?} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "notifications/initialized"
      }

      assert {:ok, nil} = Tidewave.MCP.Server.handle_message(message, config, include?)
    end

    test "handles cancelled notification", %{config: config, include_browser_tools?: include?} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "notifications/cancelled",
        "params" => %{"reason" => "test"}
      }

      assert {:ok, nil} = Tidewave.MCP.Server.handle_message(message, config, include?)
    end

    test "ignores unhandled notifications without crashing", %{
      config: config,
      include_browser_tools?: include?
    } do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "notifications/roots/list_changed"
      }

      assert {:ok, nil} = Tidewave.MCP.Server.handle_message(message, config, include?)
    end

    test "handles tools/list request", %{config: config, include_browser_tools?: include?} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "tools/list",
        "id" => "2"
      }

      assert {:ok, response} = Tidewave.MCP.Server.handle_message(message, config, include?)

      assert response["jsonrpc"] == "2.0"
      assert response["id"] == "2"
      assert is_list(response["result"]["tools"])
      assert "browser_eval" in Enum.map(response["result"]["tools"], & &1["name"])
    end

    test "does not include browser tools when disabled", %{config: config} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "tools/list",
        "id" => "2"
      }

      assert {:ok, response} = Tidewave.MCP.Server.handle_message(message, config, false)

      refute "browser_eval" in Enum.map(response["result"]["tools"], & &1["name"])
    end

    test "does not dispatch browser tools when disabled", %{config: config} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "tools/call",
        "id" => "3",
        "params" => %{"name" => "browser_eval", "arguments" => %{}}
      }

      assert {:error, error} = Tidewave.MCP.Server.handle_message(message, config, false)

      assert error["error"]["code"] == -32601
    end

    test "returns invalid arguments for malformed browser tool arguments", %{config: config} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "tools/call",
        "id" => "3",
        "params" => %{"name" => "browser_eval", "arguments" => "invalid"}
      }

      assert {:error, error} = Tidewave.MCP.Server.handle_message(message, config, true)

      assert error["error"]["code"] == -32602
      assert error["error"]["message"] == "Invalid arguments for tool"
    end

    test "handles tool calls", %{config: config, include_browser_tools?: include?} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "tools/call",
        "id" => "3",
        "params" => %{
          "name" => "project_eval",
          "arguments" => %{"code" => "1 + 1"}
        }
      }

      assert {:ok, response} = Tidewave.MCP.Server.handle_message(message, config, include?)

      assert response["jsonrpc"] == "2.0"
      assert response["id"] == "3"
      assert response["result"]["content"]
    end

    test "handles prompts/list request", %{config: config, include_browser_tools?: include?} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "prompts/list",
        "id" => "4"
      }

      assert {:ok, response} = Tidewave.MCP.Server.handle_message(message, config, include?)

      assert response["result"]["prompts"] == []
    end

    test "handles resources/list request", %{config: config, include_browser_tools?: include?} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "resources/list",
        "id" => "6"
      }

      assert {:ok, response} = Tidewave.MCP.Server.handle_message(message, config, include?)

      assert response["result"]["resources"] == []
    end

    test "handles resources/templates/list request", %{
      config: config,
      include_browser_tools?: include?
    } do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "resources/templates/list",
        "id" => "10"
      }

      assert {:ok, response} = Tidewave.MCP.Server.handle_message(message, config, include?)

      assert response["result"]["templates"] == []
    end
  end

  defp tidewave_config do
    %{
      allow_remote_access: false,
      phoenix_endpoint: nil,
      inspect_opts: [charlists: :as_lists, limit: 50, pretty: true]
    }
  end
end
