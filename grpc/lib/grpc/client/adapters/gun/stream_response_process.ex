if Code.ensure_loaded?(:gun) do
  defmodule GRPC.Client.Adapters.Gun.StreamResponseProcess do
    @moduledoc false

    # Receives the Gun messages of a single request stream (it is the stream's
    # `reply_to`) and hands them out one at a time, in arrival order, through
    # `await/2`. It stops once a terminal message has been consumed, when the
    # process that issued the request exits, or when told to via `stop/1`.

    use GenServer

    require Logger

    @closed_error {:error, {:connection_error, :closed}}

    @doc """
    Options:

      * `:gun_pid` - the Gun connection to monitor, so that waiters are not left
        hanging if it goes away
      * `:owner` - the process that issued the request; nobody is left to consume
        the response once it exits
    """
    @spec start_link(keyword()) :: GenServer.on_start()
    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, opts)
    end

    @doc """
    Returns the next message of the stream, shaped like the result of `:gun.await/3`.
    """
    @spec await(pid() | nil, timeout()) :: tuple()
    def await(nil, _timeout), do: @closed_error

    def await(pid, timeout) do
      GenServer.call(pid, {:await, timeout}, :infinity)
    catch
      :exit, _reason -> @closed_error
    end

    @spec stop(pid()) :: :ok
    def stop(pid) do
      GenServer.stop(pid, :normal)
    catch
      :exit, _reason -> :ok
    end

    @impl GenServer
    def init(opts) do
      {:ok,
       %{
         messages: :queue.new(),
         waiter: nil,
         done: false,
         gun_monitor: monitor(opts[:gun_pid]),
         owner_monitor: monitor(opts[:owner])
       }}
    end

    @impl GenServer
    def handle_call({:await, timeout}, from, state) do
      case :queue.out(state.messages) do
        {{:value, message}, messages} ->
          state = %{state | messages: messages}

          if state.done and :queue.is_empty(messages) do
            {:stop, :normal, message, state}
          else
            {:reply, message, state}
          end

        {:empty, _messages} ->
          if state.done do
            {:stop, :normal, @closed_error, state}
          else
            {:noreply, %{state | waiter: {from, start_timer(timeout)}}}
          end
      end
    end

    @impl GenServer
    def handle_info({:gun_response, _gun_pid, _stream_ref, fin, status, headers}, state) do
      push(state, {:response, fin, status, headers}, fin == :fin)
    end

    def handle_info({:gun_data, _gun_pid, _stream_ref, fin, data}, state) do
      push(state, {:data, fin, data}, fin == :fin)
    end

    def handle_info({:gun_trailers, _gun_pid, _stream_ref, trailers}, state) do
      push(state, {:trailers, trailers}, true)
    end

    def handle_info({:gun_error, _gun_pid, _stream_ref, reason}, state) do
      push(state, {:error, {:stream_error, reason}}, true)
    end

    def handle_info({:connection_down, reason}, state) do
      push(state, {:error, {:connection_error, reason}}, true)
    end

    def handle_info({:DOWN, ref, :process, _pid, reason}, %{gun_monitor: ref} = state) do
      push(state, {:error, {:down, reason}}, true)
    end

    def handle_info({:DOWN, ref, :process, _pid, _reason}, %{owner_monitor: ref} = state) do
      {:stop, :normal, state}
    end

    def handle_info({:timeout, timer, :await_timeout}, %{waiter: {from, timer}} = state) do
      GenServer.reply(from, {:error, :timeout})
      {:noreply, %{state | waiter: nil}}
    end

    def handle_info({:timeout, _stale_timer, :await_timeout}, state) do
      {:noreply, state}
    end

    def handle_info(msg, state) do
      Logger.warning("#{inspect(__MODULE__)} received unexpected message: #{inspect(msg)}")
      push(state, {:error, {:unexpected_message, inspect(msg)}}, true)
    end

    # Anything arriving after the terminal message would never be consumed.
    defp push(%{done: true} = state, _message, _terminal?), do: {:noreply, state}

    defp push(%{waiter: {from, timer}} = state, message, terminal?) do
      cancel_timer(timer)
      GenServer.reply(from, message)
      state = %{state | waiter: nil, done: terminal?}

      if terminal? do
        {:stop, :normal, state}
      else
        {:noreply, state}
      end
    end

    defp push(state, message, terminal?) do
      {:noreply, %{state | messages: :queue.in(message, state.messages), done: terminal?}}
    end

    defp monitor(pid) when is_pid(pid), do: Process.monitor(pid)
    defp monitor(nil), do: nil

    defp start_timer(:infinity), do: nil
    defp start_timer(timeout), do: :erlang.start_timer(timeout, self(), :await_timeout)

    defp cancel_timer(nil), do: :ok
    defp cancel_timer(timer), do: :erlang.cancel_timer(timer)
  end
end
