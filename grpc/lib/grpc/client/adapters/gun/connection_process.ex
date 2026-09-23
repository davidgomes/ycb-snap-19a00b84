if Code.ensure_loaded?(:gun) do
  defmodule GRPC.Client.Adapters.Gun.ConnectionProcess do
    @moduledoc false

    # Owns a Gun connection on behalf of a channel.
    #
    # Gun shuts a connection down as soon as its owner exits, so the owner has to
    # live as long as the channel instead of the process that called `connect/2`.
    # Named channels register this process in the node-local `GRPC.Client.Registry`
    # under `{ref, host, port}` so every caller on the node reuses the same
    # connection.
    #
    # Each request gets a linked `StreamResponseProcess` as its Gun `reply_to`.

    use GenServer

    require Logger

    alias GRPC.Client.Adapters.Gun.StreamResponseProcess

    @spec connect(GRPC.Channel.t(), map()) :: {:ok, pid()} | {:error, any()}
    def connect(channel, open_opts) do
      case whereis(channel) do
        nil -> start_connection(channel, open_opts)
        pid -> {:ok, pid}
      end
    end

    @spec disconnect(pid()) :: :ok
    def disconnect(pid) do
      GenServer.stop(pid)
    catch
      :exit, _reason -> :ok
    end

    @spec request(pid(), iodata(), list(), iodata()) ::
            {:ok, %{stream_ref: reference(), response_pid: pid()}} | {:error, any()}
    def request(pid, path, headers, body), do: call(pid, {:post, path, headers, body})

    @spec open_stream(pid(), iodata(), list()) ::
            {:ok, %{stream_ref: reference(), response_pid: pid()}} | {:error, any()}
    def open_stream(pid, path, headers), do: call(pid, {:post, path, headers, nil})

    @spec send_data(pid(), reference(), :fin | :nofin, iodata()) :: :ok | {:error, any()}
    def send_data(pid, stream_ref, fin, data), do: call(pid, {:send_data, stream_ref, fin, data})

    @spec cancel(pid(), reference()) :: :ok | {:error, any()}
    def cancel(pid, stream_ref), do: call(pid, {:cancel, stream_ref})

    defp call(pid, request) do
      GenServer.call(pid, request)
    catch
      :exit, {reason, {GenServer, :call, _args}} -> {:error, {:down, reason}}
    end

    # The caller opens the connection and waits for it to come up, so a slow or
    # unreachable server doesn't block GRPC.Client.Supervisor. Ownership is handed
    # over once the connection is usable.
    defp start_connection(%{host: host, port: port} = channel, open_opts) do
      {:ok, gun_pid} = open(host, port, open_opts)

      case :gun.await_up(gun_pid) do
        {:ok, :http2} ->
          hand_over(channel, gun_pid)

        {:ok, proto} ->
          :gun.shutdown(gun_pid)
          {:error, "Error when opening connection: protocol #{proto} is not http2"}

        {:error, reason} ->
          :gun.shutdown(gun_pid)
          {:error, reason}
      end
    end

    defp hand_over(channel, gun_pid) do
      case DynamicSupervisor.start_child(GRPC.Client.Supervisor, child_spec(channel, gun_pid)) do
        {:ok, pid} ->
          :ok = :gun.set_owner(gun_pid, pid)
          {:ok, pid}

        {:error, {:already_started, pid}} ->
          :gun.shutdown(gun_pid)
          {:ok, pid}

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

    defp child_spec(channel, gun_pid) do
      %{
        id: __MODULE__,
        start: {GenServer, :start_link, [__MODULE__, gun_pid, name_opts(channel)]},
        restart: :temporary,
        type: :worker,
        shutdown: 5000
      }
    end

    defp name_opts(%{ref: nil}), do: []
    defp name_opts(channel), do: [name: via(channel)]

    defp whereis(%{ref: nil}), do: nil
    defp whereis(channel), do: GenServer.whereis(via(channel))

    defp via(%{ref: ref, host: host, port: port}) do
      {:via, Registry, {GRPC.Client.Registry, {__MODULE__, ref, host, port}}}
    end

    @impl GenServer
    def init(gun_pid) do
      Process.flag(:trap_exit, true)
      Process.monitor(gun_pid)
      {:ok, %{gun_pid: gun_pid, streams: %{}}}
    end

    @impl GenServer
    def handle_call({:post, path, headers, body}, {owner, _tag}, %{gun_pid: gun_pid} = state) do
      {:ok, response_pid} = StreamResponseProcess.start_link(owner: owner)
      req_opts = %{reply_to: response_pid}

      stream_ref =
        if is_nil(body) do
          :gun.post(gun_pid, path, headers, req_opts)
        else
          :gun.post(gun_pid, path, headers, body, req_opts)
        end

      {:reply, {:ok, %{stream_ref: stream_ref, response_pid: response_pid}},
       %{state | streams: Map.put(state.streams, response_pid, stream_ref)}}
    end

    def handle_call({:send_data, stream_ref, fin, data}, _from, %{gun_pid: gun_pid} = state) do
      :ok = :gun.data(gun_pid, stream_ref, fin, data)
      {:reply, :ok, state}
    end

    def handle_call({:cancel, stream_ref}, _from, %{gun_pid: gun_pid} = state) do
      :ok = :gun.cancel(gun_pid, stream_ref)

      streams =
        case response_pid(state, stream_ref) do
          nil ->
            state.streams

          response_pid ->
            StreamResponseProcess.cancel(response_pid)
            Map.delete(state.streams, response_pid)
        end

      {:reply, :ok, %{state | streams: streams}}
    end

    @impl GenServer
    def handle_info({:EXIT, pid, reason}, %{gun_pid: gun_pid} = state) do
      case Map.pop(state.streams, pid) do
        {nil, _streams} ->
          {:noreply, state}

        {stream_ref, streams} ->
          # The stream was abandoned before Gun finished it (owner exited or timed out).
          if reason != :normal, do: :gun.cancel(gun_pid, stream_ref)
          {:noreply, %{state | streams: streams}}
      end
    end

    # Gun gave up reconnecting or crashed, so this connection can't be used anymore.
    def handle_info({:DOWN, _ref, :process, gun_pid, reason}, %{gun_pid: gun_pid} = state) do
      Enum.each(state.streams, fn {response_pid, _stream_ref} ->
        send(response_pid, {:connection_down, reason})
      end)

      {:stop, :normal, %{state | streams: %{}}}
    end

    def handle_info({:gun_up, gun_pid, _protocol}, %{gun_pid: gun_pid} = state),
      do: {:noreply, state}

    # Gun has already sent a `gun_error` to the `reply_to` of every stream it killed.
    def handle_info(
          {:gun_down, gun_pid, _protocol, _reason, _killed},
          %{gun_pid: gun_pid} = state
        ),
        do: {:noreply, state}

    # Errors for `:gun.data/4` and `:gun.cancel/2` go to their caller, which is this process.
    def handle_info({:gun_error, gun_pid, stream_ref, _reason} = msg, %{gun_pid: gun_pid} = state) do
      if response_pid = response_pid(state, stream_ref), do: send(response_pid, msg)
      {:noreply, state}
    end

    def handle_info(msg, state) do
      Logger.warning("#{inspect(__MODULE__)} received unexpected message: #{inspect(msg)}")
      {:noreply, state}
    end

    @impl GenServer
    def terminate(_reason, %{gun_pid: gun_pid}) do
      :gun.shutdown(gun_pid)
    end

    defp response_pid(%{streams: streams}, stream_ref) do
      Enum.find_value(streams, fn {response_pid, ref} -> ref == stream_ref && response_pid end)
    end
  end
end
