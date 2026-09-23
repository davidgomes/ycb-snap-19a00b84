if Code.ensure_loaded?(:gun) do
  defmodule GRPC.Client.Adapters.Gun.ConnectionOwner do
    @moduledoc false

    # Gun shuts a connection down as soon as its owner process exits. Handing
    # ownership to a supervised process decouples the connection's lifetime from
    # whichever process happened to call `connect/2`, so channels shared by name
    # keep working after that caller is gone. The owner exits once the Gun
    # connection does.

    use GenServer, restart: :temporary

    @spec take_ownership(pid()) :: :ok | {:error, term()}
    def take_ownership(gun_pid) do
      with {:ok, owner_pid} <-
             DynamicSupervisor.start_child(GRPC.Client.Supervisor, {__MODULE__, gun_pid}) do
        :gun.set_owner(gun_pid, owner_pid)
      end
    end

    def start_link(gun_pid) do
      GenServer.start_link(__MODULE__, gun_pid)
    end

    @impl true
    def init(gun_pid) do
      {:ok, Process.monitor(gun_pid)}
    end

    @impl true
    def handle_info({:DOWN, monitor_ref, :process, _pid, _reason}, monitor_ref) do
      {:stop, :normal, monitor_ref}
    end

    # Connection-level notifications (`:gun_up`, `:gun_down`, `:gun_error`) are
    # delivered to the owner; stream messages go to the process that made the request.
    def handle_info(_msg, monitor_ref) do
      {:noreply, monitor_ref}
    end
  end
end
