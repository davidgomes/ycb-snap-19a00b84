defmodule Tidewave.MCP.HTTP do
  @moduledoc false

  require Logger

  import Plug.Conn
  alias Tidewave.MCP.Handler

  def run(conn) do
    Logger.info("Received #{conn.method} message")
    params = conn.body_params
    conn = fetch_query_params(conn)
    include_browser_tools? = conn.query_params["include_browser_tools"] != "false"
    Logger.debug("Raw params: #{inspect(params, pretty: true)}")

    case Handler.handle_message(params, conn.private.tidewave_config,
           include_browser_tools: include_browser_tools?
         ) do
      :notification ->
        send_json(conn, 202, %{status: "ok"})

      {:reply, response} ->
        Logger.debug("Sending HTTP response: #{inspect(response, pretty: true)}")
        send_json(conn, 200, response)

      {:error, error_response} ->
        Logger.warning("Error handling message: #{inspect(error_response)}")
        send_json(conn, 400, error_response)
    end
  end

  defp send_json(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
  end
end
