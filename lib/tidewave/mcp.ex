defmodule Tidewave.MCP do
  @moduledoc false

  use Supervisor
  require Logger
  import Plug.Conn

  alias Tidewave.MCP

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    maybe_silence_logs()
    add_logger_backend()
    init_config()

    MCP.Server.init_tools()

    children = [
      {Registry, name: Tidewave.BrowserSessions, keys: :unique},
      Tidewave.MCP.Logger,
      Tidewave.MCP.StandardError
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Returns the working directory.
  """
  # TC relies on this function for FS operations. Don't remove!
  def root, do: Application.fetch_env!(:tidewave, :root)

  @doc """
  Returns the project name.
  """
  def project_name, do: Application.fetch_env!(:tidewave, :project_name)

  def handle_http_message(conn) do
    Logger.info("Received #{conn.method} message")
    params = conn.body_params
    conn = fetch_query_params(conn)
    include_browser_tools? = conn.query_params["include_browser_tools"] != "false"
    Logger.debug("Raw params: #{inspect(params, pretty: true)}")

    case validate_jsonrpc_message(params) do
      {:ok, message} ->
        case MCP.Server.handle_message(
               message,
               conn.private.tidewave_config,
               include_browser_tools?
             ) do
          {:ok, nil} ->
            # Notifications that don't return a response
            conn |> put_status(202) |> send_json(%{status: "ok"})

          {:ok, response} ->
            Logger.debug("Sending HTTP response: #{inspect(response, pretty: true)}")
            conn |> put_status(200) |> send_json(response)

          {:error, error_response} ->
            Logger.warning("Error handling message: #{inspect(error_response)}")
            conn |> put_status(400) |> send_json(error_response)
        end

      {:error, :invalid_jsonrpc} ->
        Logger.warning("Invalid JSON-RPC message format")
        send_jsonrpc_error(conn, nil, -32600, "Could not parse message")
    end
  end

  defp validate_jsonrpc_message(%{"jsonrpc" => "2.0"} = message) do
    cond do
      # Request must have method and id (string or number)
      Map.has_key?(message, "id") and Map.has_key?(message, "method") ->
        case message["id"] do
          id when is_binary(id) or is_number(id) -> {:ok, message}
          _ -> {:error, :invalid_jsonrpc}
        end

      # Notification must have method but no id
      not Map.has_key?(message, "id") and Map.has_key?(message, "method") ->
        {:ok, message}

      # reply (e.g. to ping) with ID + result
      Map.has_key?(message, "id") and Map.has_key?(message, "result") ->
        {:ok, message}

      true ->
        {:error, :invalid_jsonrpc}
    end
  end

  defp validate_jsonrpc_message(_), do: {:error, :invalid_jsonrpc}

  defp send_json(conn, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(conn.status || 200, Jason.encode!(data))
  end

  defp send_jsonrpc_error(conn, id, code, message, data \\ nil) do
    error = %{
      code: code,
      message: message
    }

    error = if data, do: Map.put(error, :data, data), else: error

    response = %{
      jsonrpc: "2.0",
      id: id,
      error: error
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(response))
  end

  defp maybe_silence_logs do
    if Application.get_env(:tidewave, :debug) do
      :ok
    else
      Logger.put_module_level(MCP.Connection, :none)
      Logger.put_module_level(MCP.Server, :none)
    end
  end

  defp add_logger_backend() do
    :ok =
      :logger.add_handler(
        MCP.Logger,
        MCP.Logger,
        %{formatter: Logger.default_formatter(colors: [enabled: false])}
      )
  end

  defp init_config() do
    if Application.get_env(:tidewave, :root) == nil do
      Application.put_env(:tidewave, :root, File.cwd!())
    end

    if System.find_executable("git") &&
         match?({_, 0}, System.cmd("git", ["rev-parse", "--show-toplevel"])) do
      :ok
    else
      Logger.warning(
        "Some Tidewave tools are only available for codebases using `git`. " <>
          "Make sure `git` is installed and run `git init` before continuing"
      )
    end

    if Application.get_env(:tidewave, :project_name) == nil do
      if module = Mix.Project.get() do
        project_name = module |> Module.split() |> hd() |> Macro.underscore()
        Application.put_env(:tidewave, :project_name, project_name)
      else
        raise """
        tidewave could not determine the current project, please specify a name in your config.exs:

            config :tidewave, :project_name, "my_project"
        """
      end
    end
  end
end
