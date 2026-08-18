defmodule Tidewave.MCP.Transport.HTTPTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn
  import ExUnit.CaptureLog

  @moduletag :capture_log

  describe "handle_http_message/1" do
    test "returns error for invalid JSON-RPC message" do
      message = %{"invalid" => "message"}

      log =
        capture_log([level: :warning], fn ->
          conn = %{mcp_conn() | body_params: message}
          response = Tidewave.MCP.Transport.HTTP.handle_http_message(conn)

          assert response.status == 200
          response_body = Jason.decode!(response.resp_body)
          assert response_body["error"]["code"] == -32600
          assert response_body["error"]["message"] == "Could not parse message"
        end)

      assert log =~ "Invalid JSON-RPC message format"
    end
  end

  defp mcp_conn(path \\ "/tidewave/mcp") do
    conn(:post, path, %{})
    |> put_req_header("content-type", "application/json")
    |> put_private(:tidewave_config, %{
      allow_remote_access: false,
      phoenix_endpoint: nil,
      inspect_opts: [charlists: :as_lists, limit: 50, pretty: true]
    })
  end
end
