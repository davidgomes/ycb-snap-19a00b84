if Code.ensure_loaded?(:gun) do
  defmodule GRPC.Client.Adapters.Gun.ConnectionProcess do
    @moduledoc false

    # Owns a Gun connection on behalf of the adapter. Gun closes a connection as
    # soon as its owner exits, so leaving ownership with whichever process called
    # `connect/2` would tie long-lived (e.g. named) channels to that caller.
    #
    # The process runs under `GRPC.Client.Supervisor` and stops when the Gun
    # connection goes away. Responses are delivered to one
    # `GRPC.Client.Adapters.Gun.StreamResponseProcess` per request stream.

    use GenServer

    alias GRPC.Client.Adapters.Gun.StreamResponseProcess

    require Logger

    @doc """
    Opens a Gun connection for `channel` and hands it over to a supervised
    connection process.

    Channels with a `ref` share the connection process of the same ref, host and
    port, so connecting again with the same name does not open a new connection.
    """
    @spec connect(GRPC.Channel.t(), map()) :: {:ok, %{conn_pid: pid()}} | {:error, any()}
    def connect(channel, open_opts) do
      case lookup(channel) do
        {:ok, pid} ->
          {:ok, %{conn_pid: pid}}

        :error ->
          with {:ok, gun_pid} <- open(channel, open_opts) do
            start_owner(channel, gun_pid)
          end
      end
    end

    @spec disconnect(pid()) :: :ok
    def disconnect(pid) do
      GenServer.stop(pid, :normal)
    catch
      :exit, _reason -> :ok
    end

    @spec request(pid(), iodata(), list(), iodata()) ::
            {:ok, %{stream_ref: reference(), response_pid: pid()}} | {:error, :closed}
    def request(pid, path, headers, body) do
      call(pid, {:post, path, headers, body})
    end

    @spec open_stream(pid(), iodata(), list()) ::
            {:ok, %{stream_ref: reference(), response_pid: pid()}} | {:error, :closed}
    def open_stream(pid, path, headers) do
      call(pid, {:post, path, headers, nil})
    end

    @spec send_data(pid(), reference(), :fin | :nofin, iodata()) :: :ok | {:error, :closed}
    def send_data(pid, stream_ref, fin, data) do
      call(pid, {:data, stream_ref, fin, data})
    end

    @spec cancel(pid(), reference()) :: :ok
    def cancel(pid, stream_ref) do
      call(pid, {:cancel, stream_ref})
      :ok
    end

    @spec start_link(GRPC.Channel.t(), pid()) :: GenServer.on_start()
    def start_link(channel, gun_pid) do
      case name(channel) do
        nil -> GenServer.start_link(__MODULE__, gun_pid)
        name -> GenServer.start_link(__MODULE__, gun_pid, name: {:via, Registry, name})
      end
    end

    @impl GenServer
    def init(gun_pid) do
      {:ok,
       %{
         gun_pid: gun_pid,
         gun_monitor: Process.monitor(gun_pid),
         streams: %{},
         stream_monitors: %{}
       }}
    end

    @impl GenServer
    def handle_call({:post, path, headers, body}, {caller, _tag}, %{gun_pid: gun_pid} = state) do
      {:ok, response_pid} = StreamResponseProcess.start_link(gun_pid: gun_pid, owner: caller)
      req_opts = %{reply_to: response_pid}

      stream_ref =
        case body do
          nil -> :gun.post(gun_pid, path, headers, req_opts)
          body -> :gun.post(gun_pid, path, headers, body, req_opts)
        end

      {:reply, {:ok, %{stream_ref: stream_ref, response_pid: response_pid}},
       track(state, stream_ref, response_pid)}
    end

    def handle_call({:data, stream_ref, fin, data}, _from, %{gun_pid: gun_pid} = state) do
      {:reply, :gun.data(gun_pid, stream_ref, fin, data), state}
    end

    def handle_call({:cancel, stream_ref}, _from, %{gun_pid: gun_pid} = state) do
      :ok = :gun.cancel(gun_pid, stream_ref)

      case Map.fetch(state.streams, stream_ref) do
        {:ok, {response_pid, _monitor}} ->
          state = untrack(state, stream_ref)
          StreamResponseProcess.stop(response_pid)
          {:reply, :ok, state}

        :error ->
          {:reply, :ok, state}
      end
    end

    @impl GenServer
    def handle_info({:gun_up, _gun_pid, _protocol}, state), do: {:noreply, state}

    def handle_info({:gun_down, _gun_pid, _protocol, reason, killed_streams}, state) do
      state =
        Enum.reduce(killed_streams, state, fn stream_ref, state ->
          case Map.fetch(state.streams, stream_ref) do
            {:ok, {response_pid, _monitor}} ->
              send(response_pid, {:connection_down, reason})
              untrack(state, stream_ref)

            :error ->
              state
          end
        end)

      {:noreply, state}
    end

    # Errors caused by `:gun.data/4` and `:gun.cancel/2` are sent to this process,
    # as it is the one calling them.
    def handle_info({:gun_error, _gun_pid, stream_ref, _reason} = msg, state) do
      case Map.fetch(state.streams, stream_ref) do
        {:ok, {response_pid, _monitor}} -> send(response_pid, msg)
        :error -> :ok
      end

      {:noreply, state}
    end

    def handle_info({:DOWN, ref, :process, _pid, _reason}, %{gun_monitor: ref} = state) do
      {:stop, :normal, state}
    end

    def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
      case Map.fetch(state.stream_monitors, ref) do
        {:ok, stream_ref} -> {:noreply, untrack(state, stream_ref)}
        :error -> {:noreply, state}
      end
    end

    def handle_info(msg, state) do
      Logger.warning("#{inspect(__MODULE__)} received unexpected message: #{inspect(msg)}")
      {:noreply, state}
    end

    @impl GenServer
    def terminate(_reason, %{gun_pid: gun_pid}) do
      :gun.shutdown(gun_pid)
    end

    defp open(%{host: host, port: port}, open_opts) do
      {:ok, gun_pid} = open(host, port, open_opts)

      case :gun.await_up(gun_pid) do
        {:ok, :http2} ->
          {:ok, gun_pid}

        {:ok, proto} ->
          :gun.shutdown(gun_pid)
          {:error, "Error when opening connection: protocol #{proto} is not http2"}

        {:error, reason} ->
          :gun.shutdown(gun_pid)
          {:error, reason}
      end
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

    defp start_owner(channel, gun_pid) do
      child_spec = %{
        id: __MODULE__,
        start: {__MODULE__, :start_link, [channel, gun_pid]},
        restart: :temporary
      }

      case DynamicSupervisor.start_child(GRPC.Client.Supervisor, child_spec) do
        {:ok, pid} ->
          :ok = :gun.set_owner(gun_pid, pid)
          {:ok, %{conn_pid: pid}}

        {:error, {:already_started, pid}} ->
          :gun.shutdown(gun_pid)
          {:ok, %{conn_pid: pid}}

        {:error, reason} ->
          :gun.shutdown(gun_pid)
          {:error, reason}
      end
    end

    defp lookup(channel) do
      case name(channel) do
        nil ->
          :error

        {registry, key} ->
          case Registry.lookup(registry, key) do
            [{pid, _value}] -> {:ok, pid}
            [] -> :error
          end
      end
    end

    defp name(%{ref: nil}), do: nil

    defp name(%{ref: ref, host: host, port: port}),
      do: {GRPC.Client.Registry, {__MODULE__, ref, host, port}}

    defp call(pid, request) do
      GenServer.call(pid, request)
    catch
      :exit, _reason -> {:error, :closed}
    end

    defp track(state, stream_ref, response_pid) do
      monitor = Process.monitor(response_pid)

      %{
        state
        | streams: Map.put(state.streams, stream_ref, {response_pid, monitor}),
          stream_monitors: Map.put(state.stream_monitors, monitor, stream_ref)
      }
    end

    defp untrack(state, stream_ref) do
      case Map.pop(state.streams, stream_ref) do
        {{_response_pid, monitor}, streams} ->
          Process.demonitor(monitor, [:flush])
          %{state | streams: streams, stream_monitors: Map.delete(state.stream_monitors, monitor)}

        {nil, _streams} ->
          state
      end
    end
  end
end
