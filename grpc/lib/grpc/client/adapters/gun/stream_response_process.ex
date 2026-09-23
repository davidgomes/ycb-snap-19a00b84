if Code.ensure_loaded?(:gun) do
  defmodule GRPC.Client.Adapters.Gun.StreamResponseProcess do
    @moduledoc false

    # Receives the Gun messages of a single request stream (Gun delivers them here
    # through the `:reply_to` request option) and hands them to the reader in
    # arrival order, in the same shapes `:gun.await/3` returns.
    #
    # The process stops once the reader has consumed a terminal message, when a
    # read times out, when the stream is cancelled, or when its owner (the process
    # that issued the request) exits, so abandoned streams don't leak processes.

    use GenServer

    require Logger

    @closed_error {:error, {:connection_error, :closed}}

    @spec start_link(pid()) :: GenServer.on_start()
    def start_link(owner \\ self()) do
      GenServer.start_link(__MODULE__, owner)
    end

    @spec await(pid(), timeout()) :: tuple()
    def await(pid, timeout) do
      GenServer.call(pid, {:await, timeout}, :infinity)
    catch
      :exit, _reason ->
        @closed_error
    end

    @spec cancel(pid()) :: :ok
    def cancel(pid) do
      GenServer.cast(pid, :cancel)
    end

    @impl GenServer
    def init(owner) do
      Process.monitor(owner)
      {:ok, %{messages: :queue.new(), waiter: nil, done: false}}
    end

    @impl GenServer
    def handle_call({:await, timeout}, from, %{messages: messages} = state) do
      case :queue.out(messages) do
        {{:value, message}, remaining} ->
          new_state = %{state | messages: remaining}

          if state.done and :queue.is_empty(remaining) do
            {:stop, :normal, message, new_state}
          else
            {:reply, message, new_state}
          end

        {:empty, _} ->
          {:noreply, %{state | waiter: {from, start_timer(timeout)}}}
      end
    end

    @impl GenServer
    def handle_cast(:cancel, state) do
      {:stop, :normal, state}
    end

    @impl GenServer
    def handle_info({:timeout, timer_ref, :await}, %{waiter: {from, timer_ref}} = state) do
      GenServer.reply(from, {:error, :timeout})
      {:stop, :normal, %{state | waiter: nil}}
    end

    def handle_info({:timeout, _timer_ref, :await}, state), do: {:noreply, state}

    def handle_info({:DOWN, _ref, :process, _owner, _reason}, state) do
      {:stop, :normal, state}
    end

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

    def handle_info(msg, state) do
      Logger.warning("#{inspect(__MODULE__)} received unexpected message: #{inspect(msg)}")
      push(state, {:error, {:unexpected_message, inspect(msg)}}, true)
    end

    # Nothing can follow a terminal message on a stream, e.g. a connection error
    # reported after the trailers already arrived.
    defp push(%{done: true} = state, _message, _terminal?), do: {:noreply, state}

    defp push(%{waiter: {from, timer_ref}} = state, message, terminal?) do
      cancel_timer(timer_ref)
      GenServer.reply(from, message)
      new_state = %{state | waiter: nil, done: terminal?}

      if terminal? do
        {:stop, :normal, new_state}
      else
        {:noreply, new_state}
      end
    end

    defp push(%{messages: messages} = state, message, terminal?) do
      {:noreply, %{state | messages: :queue.in(message, messages), done: terminal?}}
    end

    defp start_timer(:infinity), do: nil
    defp start_timer(timeout), do: :erlang.start_timer(timeout, self(), :await)

    defp cancel_timer(nil), do: :ok
    defp cancel_timer(timer_ref), do: Process.cancel_timer(timer_ref, async: true, info: false)
  end
end
