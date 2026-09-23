defmodule BroadwayKafka.SharedClient do
  @moduledoc false

  # Ties the lifetime of a :brod client shared by all producers to the
  # Broadway pipeline. The client itself runs under :brod's supervisor,
  # which delays restarts while Kafka is unreachable, instead of under
  # Broadway's supervisor, which would quickly exhaust its max restarts.

  use GenServer

  def start_link({hosts, client_id, client_config}) do
    GenServer.start_link(__MODULE__, {hosts, client_id, client_config})
  end

  @impl true
  def init({hosts, client_id, client_config}) do
    Process.flag(:trap_exit, true)

    case :brod.start_client(hosts, client_id, client_config) do
      :ok -> {:ok, client_id}
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def terminate(_reason, client_id) do
    :brod.stop_client(client_id)
  end
end
