if Code.ensure_loaded?(:gun) do
  defmodule GRPC.Client.Adapters.Gun.ConnectionProcess do
    @moduledoc false

    # Owns a Gun connection on behalf of the Gun adapter. Gun closes a connection
    # when its owner exits, so the connection can't be owned by whichever process
    # happened to call `GRPC.Stub.connect/2`: named channels outlive that caller.
    #
    # These processes run under `GRPC.Client.Supervisor` and are registered in
    # `GRPC.Client.Registry` per `{channel ref, host, port}`, so connecting again
    # with the same name reuses the existing connection on this node.
    #
    # Gun delivers response messages directly to one
    # `GRPC.Client.Adapters.Gun.StreamResponseProcess` per request. This process
    # only tracks them so it can report connection failures, which Gun sends to
    # the owner alone.

    use GenServer

    require Logger

    alias GRPC.Client.Adapters.Gun.StreamResponseProcess

    @up_timeout 5_000

    @spec connect(GRPC.Channel.t(), map()) :: {:ok, pid()} | {:error, any()}
    def connect(channel, open_opts) when is_map(open_opts) do
      case DynamicSupervisor.start_child(GRPC.Client.Supervisor, child_spec(channel, open_opts)) do
        {:ok, pid} -> await_up(pid)
        {:error, {:already_started, pid}} -> await_up(pid)
        {:error, reason} -> {:error, reason}
      end
    end

    @spec disconnect(pid()) :: :ok
    def disconnect(pid) do
      GenServer.call(pid, :disconnect)
    catch
      :exit, _reason ->
        :ok
    end

    @spec request(pid(), iodata(), list(), iodata()) ::
            {:ok, %{stream_ref: reference(), response_pid: pid()}}
    def request(pid, path, headers, body) do
      GenServer.call(pid, {:request, path, headers, body})
    end

    @spec open_stream(pid(), iodata(), list()) ::
            {:ok, %{stream_ref: reference(), response_pid: pid()}}
    def open_stream(pid, path, headers) do
      GenServer.call(pid, {:request, path, headers, nil})
    end

    @spec send_data(pid(), reference(), :fin | :nofin, iodata()) :: :ok
    def send_data(pid, stream_ref, fin, data) do
      GenServer.cast(pid, {:send_data, stream_ref, fin, data})
    end

    @spec cancel(pid(), reference()) :: :ok
    def cancel(pid, stream_ref) do
      GenServer.cast(pid, {:cancel, stream_ref})
    end

    @doc false
    @spec start_link(GRPC.Channel.t(), map()) :: GenServer.on_start()
    def start_link(channel, open_opts) do
      case registry_key(channel) do
        nil ->
          GenServer.start_link(__MODULE__, {channel, open_opts, nil})

        key ->
          GenServer.start_link(__MODULE__, {channel, open_opts, key},
            name: {:via, Registry, {GRPC.Client.Registry, key}}
          )
      end
    end

    defp child_spec(channel, open_opts) do
      %{
        id: __MODULE__,
        start: {__MODULE__, :start_link, [channel, open_opts]},
        restart: :temporary
      }
    end

    defp registry_key(%{ref: nil}), do: nil
    defp registry_key(%{ref: ref, host: host, port: port}), do: {__MODULE__, ref, host, port}

    # Waiting for the connection to come up happens here rather than in `init/1`
    # so that slow or unreachable servers don't block `GRPC.Client.Supervisor`.
    defp await_up(pid) do
      case GenServer.call(pid, :await_up, :infinity) do
        :ok -> {:ok, pid}
        {:error, reason} -> {:error, reason}
      end
    catch
      :exit, {reason, _} ->
        {:error, reason}
    end

    @impl GenServer
    def init({%{host: host, port: port}, open_opts, registry_key}) do
      # Response processes are linked so they die with this process, but one of
      # them crashing must not take the whole connection down.
      Process.flag(:trap_exit, true)

      case open(host, port, open_opts) do
        {:ok, gun_pid} ->
          {:ok,
           %{
             gun_pid: gun_pid,
             gun_ref: Process.monitor(gun_pid),
             registry_key: registry_key,
             status: :connecting,
             up_waiters: [],
             up_timer: Process.send_after(self(), :up_timeout, @up_timeout),
             streams: %{}
           }}

        {:error, reason} ->
          {:stop, reason}
      end
    end

    @impl GenServer
    def handle_call(:await_up, from, %{status: :connecting} = state) do
      {:noreply, %{state | up_waiters: [from | state.up_waiters]}}
    end

    def handle_call(:await_up, _from, %{status: :up} = state) do
      {:reply, :ok, state}
    end

    def handle_call(:await_up, _from, %{status: :closing} = state) do
      {:reply, {:error, :closing}, state}
    end

    def handle_call(:disconnect, _from, state) do
      {:reply, :ok, close(state)}
    end

    def handle_call({:request, path, headers, body}, {caller, _tag}, state) do
      {:ok, response_pid} = StreamResponseProcess.start_link(caller)
      stream_ref = post(state.gun_pid, path, headers, body, %{reply_to: response_pid})
      streams = Map.put(state.streams, response_pid, stream_ref)

      {:reply, {:ok, %{stream_ref: stream_ref, response_pid: response_pid}},
       %{state | streams: streams}}
    end

    @impl GenServer
    def handle_cast({:send_data, stream_ref, fin, data}, state) do
      :ok = :gun.data(state.gun_pid, stream_ref, fin, data)
      {:noreply, state}
    end

    def handle_cast({:cancel, stream_ref}, state) do
      :ok = :gun.cancel(state.gun_pid, stream_ref)
      {:noreply, state}
    end

    @impl GenServer
    def handle_info({:gun_up, gun_pid, :http2}, %{gun_pid: gun_pid, status: :connecting} = state) do
      Process.cancel_timer(state.up_timer)
      reply_up_waiters(state, :ok)
      {:noreply, %{state | status: :up, up_waiters: [], up_timer: nil}}
    end

    def handle_info({:gun_up, gun_pid, protocol}, %{gun_pid: gun_pid, status: :connecting} = state) do
      fail_connect(state, "Error when opening connection: protocol #{protocol} is not http2")
    end

    def handle_info({:gun_up, gun_pid, _protocol}, %{gun_pid: gun_pid} = state) do
      {:noreply, state}
    end

    def handle_info(:up_timeout, %{status: :connecting} = state) do
      fail_connect(state, :timeout)
    end

    def handle_info(:up_timeout, state), do: {:noreply, state}

    def handle_info({:gun_down, gun_pid, _protocol, reason, killed_streams}, %{gun_pid: gun_pid} = state) do
      killed_streams = MapSet.new(killed_streams)

      for {response_pid, stream_ref} <- state.streams,
          MapSet.member?(killed_streams, stream_ref) do
        send(response_pid, {:connection_down, reason})
      end

      {:noreply, state}
    end

    # Replies to our own `:gun.data/4` and `:gun.cancel/2` calls, e.g. when
    # writing to a stream the server already closed.
    def handle_info({:gun_error, gun_pid, stream_ref, _reason} = msg, %{gun_pid: gun_pid} = state) do
      case Enum.find(state.streams, fn {_response_pid, ref} -> ref == stream_ref end) do
        {response_pid, _stream_ref} -> send(response_pid, msg)
        nil -> :ok
      end

      {:noreply, state}
    end

    def handle_info({:DOWN, gun_ref, :process, _gun_pid, reason}, %{gun_ref: gun_ref} = state) do
      unregister(state)
      reply_up_waiters(state, {:error, {:down, reason}})

      for {response_pid, _stream_ref} <- state.streams do
        send(response_pid, {:connection_down, reason})
      end

      {:stop, :normal, state}
    end

    def handle_info({:EXIT, response_pid, _reason}, state) do
      {:noreply, %{state | streams: Map.delete(state.streams, response_pid)}}
    end

    def handle_info(msg, state) do
      Logger.warning("#{inspect(__MODULE__)} received unexpected message: #{inspect(msg)}")
      {:noreply, state}
    end

    defp fail_connect(state, reason) do
      state = close(state)
      reply_up_waiters(state, {:error, reason})
      {:noreply, %{state | up_waiters: []}}
    end

    # The process keeps running until Gun exits, so that in-flight streams can
    # finish during a graceful shutdown and are told if they don't. It leaves the
    # registry right away so that a new connect with the same name starts afresh.
    defp close(%{status: :closing} = state), do: state

    defp close(state) do
      unregister(state)
      :ok = :gun.shutdown(state.gun_pid)
      %{state | status: :closing}
    end

    defp unregister(%{registry_key: nil}), do: :ok
    defp unregister(%{registry_key: key}), do: Registry.unregister(GRPC.Client.Registry, key)

    defp reply_up_waiters(%{up_waiters: waiters}, reply) do
      Enum.each(waiters, &GenServer.reply(&1, reply))
    end

    defp post(gun_pid, path, headers, nil, req_opts),
      do: :gun.post(gun_pid, path, headers, req_opts)

    defp post(gun_pid, path, headers, body, req_opts),
      do: :gun.post(gun_pid, path, headers, body, req_opts)

    defp open({:local, socket_path}, _port, open_opts), do: :gun.open_unix(socket_path, open_opts)
    defp open(host, port, open_opts), do: :gun.open(parse_address(host), port, open_opts)

    defp parse_address(host) do
      host = String.to_charlist(host)

      case :inet.parse_address(host) do
        {:ok, address} -> address
        {:error, _} -> host
      end
    end
  end
end
