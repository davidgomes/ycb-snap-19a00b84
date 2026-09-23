if Code.ensure_loaded?(:gun) do
  defmodule GRPC.Client.Adapters.Gun.StreamResponseProcess do
    @moduledoc false

    # Buffers the Gun messages of a single request stream (it is the request's
    # `reply_to`) and hands them out in arrival order through `await/2`.
    #
    # It stops once a terminal message has been consumed. It also stops when its
    # owner (the process that opened the stream) exits or an await times out,
    # because nobody will read the stream afterwards; the connection process then
    # cancels the Gun stream.

    use GenServer

    require Logger

    @terminated_stream_error {:error, {:connection_error, :closed}}

    @spec start_link(keyword()) :: GenServer.on_start()
    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, opts)
    end

    @spec await(pid(), timeout()) :: tuple()
    def await(pid, timeout) do
      GenServer.call(pid, {:await, timeout}, :infinity)
    catch
      :exit, _reason -> @terminated_stream_error
    end

    @spec cancel(pid()) :: :ok
    def cancel(pid) do
      send(pid, :cancel)
      :ok
    end

    @impl GenServer
    def init(opts) do
      owner_ref = if owner = opts[:owner], do: Process.monitor(owner)
      {:ok, %{messages: :queue.new(), waiter: nil, done: false, owner_ref: owner_ref}}
    end

    @impl GenServer
    def handle_call({:await, timeout}, from, %{messages: messages, done: done?} = state) do
      case :queue.out(messages) do
        {{:value, message}, remaining} ->
          state = %{state | messages: remaining}

          if done? and :queue.is_empty(remaining) do
            {:stop, :normal, message, state}
          else
            {:reply, message, state}
          end

        {:empty, _} when done? ->
          {:stop, :normal, @terminated_stream_error, state}

        {:empty, _} ->
          {:noreply, %{state | waiter: {from, start_timer(timeout)}}}
      end
    end

    @impl GenServer
    def handle_info({:gun_response, _conn_pid, _stream_ref, fin, status, headers}, state),
      do: push_message(state, {:response, fin, status, headers}, fin == :fin)

    def handle_info({:gun_data, _conn_pid, _stream_ref, fin, data}, state),
      do: push_message(state, {:data, fin, data}, fin == :fin)

    def handle_info({:gun_trailers, _conn_pid, _stream_ref, trailers}, state),
      do: push_message(state, {:trailers, trailers}, true)

    def handle_info({:gun_error, _conn_pid, _stream_ref, reason}, state),
      do: push_message(state, {:error, {:stream_error, reason}}, true)

    def handle_info({:gun_error, _conn_pid, reason}, state),
      do: push_message(state, {:error, {:connection_error, reason}}, true)

    def handle_info({:connection_down, reason}, state),
      do: push_message(state, {:error, {:connection_error, reason}}, true)

    def handle_info({:timeout, timer_ref, :await}, %{waiter: {from, timer_ref}} = state) do
      GenServer.reply(from, {:error, :timeout})
      {:stop, {:shutdown, :timeout}, %{state | waiter: nil}}
    end

    def handle_info({:timeout, _timer_ref, :await}, state), do: {:noreply, state}

    def handle_info(
          {:DOWN, owner_ref, :process, _owner, _reason},
          %{owner_ref: owner_ref} = state
        ) do
      if state.done do
        {:stop, :normal, state}
      else
        {:stop, {:shutdown, :owner_down}, state}
      end
    end

    def handle_info(:cancel, state), do: {:stop, :normal, state}

    def handle_info(msg, state) do
      Logger.warning("#{inspect(__MODULE__)} received unexpected message: #{inspect(msg)}")
      push_message(state, {:error, {:unexpected_message, inspect(msg)}}, true)
    end

    defp push_message(%{done: true} = state, _message, _terminal?), do: {:noreply, state}

    defp push_message(%{waiter: {from, timer_ref}} = state, message, terminal?) do
      cancel_timer(timer_ref)
      GenServer.reply(from, message)
      state = %{state | waiter: nil, done: terminal?}

      if terminal? do
        {:stop, :normal, state}
      else
        {:noreply, state}
      end
    end

    defp push_message(%{messages: messages} = state, message, terminal?) do
      {:noreply, %{state | messages: :queue.in(message, messages), done: terminal?}}
    end

    defp start_timer(:infinity), do: nil

    defp start_timer(timeout) when is_integer(timeout),
      do: :erlang.start_timer(timeout, self(), :await)

    defp cancel_timer(nil), do: :ok

    defp cancel_timer(timer_ref) do
      :erlang.cancel_timer(timer_ref)
      :ok
    end
  end
end
