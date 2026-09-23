if Code.ensure_loaded?(:gun) do
  defmodule GRPC.Client.Adapters.Gun.ConnectionProcess do
    @moduledoc false

    # Gun ties a connection's lifecycle to the process that opened it (its owner).
    # This process opens and owns the Gun connection so that it is decoupled from
    # the (possibly short-lived) process that called `connect`. It stops once the
    # Gun connection goes away, e.g. after `:gun.shutdown/1`.

    use GenServer, restart: :temporary

    require Logger

    @spec start(term(), :inet.port_number(), map()) :: {:ok, pid()} | {:error, term()}
    def start(host, port, open_opts) do
      DynamicSupervisor.start_child(GRPC.Client.Supervisor, {__MODULE__, {host, port, open_opts}})
    end

    def start_link(args), do: GenServer.start_link(__MODULE__, args)

    @spec await_up(pid()) :: {:ok, pid()} | {:error, term()}
    def await_up(pid), do: GenServer.call(pid, :await_up, :infinity)

    @impl true
    def init({host, port, open_opts}) do
      case open(host, port, open_opts) do
        {:ok, gun_pid} ->
          ref = Process.monitor(gun_pid)
          {:ok, %{gun_pid: gun_pid, monitor_ref: ref, up: nil}, {:continue, :await_up}}

        {:error, reason} ->
          {:stop, reason}
      end
    end

    # Awaiting in handle_continue guarantees the `gun_up` message is consumed here
    # rather than by handle_info, even if it arrives before the `:await_up` call.
    @impl true
    def handle_continue(:await_up, %{gun_pid: gun_pid} = state) do
      up =
        case :gun.await_up(gun_pid, state.monitor_ref) do
          {:ok, :http2} ->
            {:ok, gun_pid}

          {:ok, proto} ->
            :gun.shutdown(gun_pid)
            {:error, "Error when opening connection: protocol #{proto} is not http2"}

          {:error, reason} ->
            :gun.shutdown(gun_pid)
            {:error, reason}
        end

      {:noreply, %{state | up: up}}
    end

    @impl true
    def handle_call(:await_up, _from, %{up: {:ok, _} = up} = state) do
      {:reply, up, state}
    end

    def handle_call(:await_up, _from, %{up: error} = state) do
      {:stop, :normal, error, state}
    end

    @impl true
    def handle_info({:DOWN, ref, :process, _pid, _reason}, %{monitor_ref: ref} = state) do
      {:stop, :normal, state}
    end

    def handle_info({:gun_up, _pid, _proto}, state), do: {:noreply, state}
    def handle_info({:gun_down, _pid, _proto, _reason, _killed}, state), do: {:noreply, state}

    def handle_info(msg, state) do
      Logger.debug("#{inspect(__MODULE__)} received unexpected message: #{inspect(msg)}")
      {:noreply, state}
    end

    defp open({:local, socket_path}, _port, open_opts),
      do: :gun.open_unix(socket_path, open_opts)

    defp open(host, port, open_opts),
      do: :gun.open(parse_address(host), port, open_opts)

    defp parse_address(host) do
      host = String.to_charlist(host)

      case :inet.parse_address(host) do
        {:ok, address} -> address
        {:error, _} -> host
      end
    end
  end
end
