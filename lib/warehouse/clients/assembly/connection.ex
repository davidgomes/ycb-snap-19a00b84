defmodule Warehouse.Clients.Assembly.Connection do
  @moduledoc """
  A basic GenServer responsible for keeping the HTTPS gRPC connection to the
  assembly microservice alive.
  """

  use GenServer

  require Logger

  @reconnect_interval_ms :timer.seconds(5)

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Returns the channel used to talk to the assembly service, or an error when the
  connection is not running at all.

  ## Examples

      iex> channel()
      {:ok, %GRPC.Channel{}}

  """
  @spec channel() :: {:ok, GRPC.Channel.t()} | {:error, :not_started}
  def channel() do
    case GenServer.whereis(__MODULE__) do
      nil -> {:error, :not_started}
      pid -> GenServer.call(pid, :channel)
    end
  end

  @impl true
  def init(_) do
    Logger.debug("Warehouse.Clients.Assembly.Connection connecting to gateway at #{config(:url)}")

    case GRPC.Stub.connect(config(:url), assembly_service_options()) do
      {:ok, channel} ->
        Logger.debug("Warehouse.Clients.Assembly.Connection connected")
        {:ok, channel}

      {:error, reason} ->
        Logger.error("Warehouse.Clients.Assembly.Connection could not connect", resource: inspect(reason))
        Process.sleep(@reconnect_interval_ms)
        init(:ok)
    end
  end

  @impl true
  def handle_call(:channel, _from, channel) do
    {:reply, {:ok, channel}, channel}
  end

  # `gun` reconnects on its own and keeps the same connection process, so the
  # channel we already hold stays valid and we must not open a second one.
  @impl true
  def handle_info({:gun_up, _conn_pid, protocol}, channel) do
    Logger.debug("Warehouse.Clients.Assembly.Connection connected over #{protocol}")
    {:noreply, channel}
  end

  @impl true
  def handle_info({:gun_down, _conn_pid, _protocol, reason, _killed_streams}, channel) do
    Logger.debug("Warehouse.Clients.Assembly.Connection disconnected", resource: inspect(reason))
    {:noreply, channel}
  end

  @impl true
  def handle_info(message, channel) do
    Logger.debug("Warehouse.Clients.Assembly.Connection ignoring message", resource: inspect(message))
    {:noreply, channel}
  end

  defp assembly_service_options() do
    options = [
      interceptors: [GRPC.Logger.Client]
    ]

    if config(:ssl, true) do
      Keyword.put(options, :cred, GRPC.Credential.new([]))
    else
      options
    end
  end

  defp config(key, default \\ nil) do
    config = Application.get_env(:warehouse, __MODULE__)
    Keyword.get(config, key, default)
  end
end
