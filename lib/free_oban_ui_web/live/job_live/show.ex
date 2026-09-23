defmodule FreeObanUiWeb.JobLive.Show do
  use FreeObanUiWeb, :live_view

  import FreeObanUiWeb.JobLive.Components

  alias FreeObanUi.Jobs

  @refresh_interval :timer.seconds(1)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: schedule_refresh()

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    job = Jobs.get_job!(id)

    {:noreply,
     socket
     |> assign(:page_title, "Job #{job.id}")
     |> assign(:job, job)}
  end

  @impl true
  def handle_event("retry", _params, socket) do
    :ok = Jobs.retry_job(socket.assigns.job)

    {:noreply, socket |> put_flash(:info, "Job retried") |> reload_job()}
  end

  def handle_event("cancel", _params, socket) do
    :ok = Jobs.cancel_job(socket.assigns.job)

    {:noreply, socket |> put_flash(:info, "Job cancelled") |> reload_job()}
  end

  def handle_event("delete", _params, socket) do
    :ok = Jobs.delete_job(socket.assigns.job)

    case Jobs.get_job(socket.assigns.job.id) do
      nil ->
        {:noreply, socket |> put_flash(:info, "Job deleted") |> push_navigate(to: ~p"/jobs")}

      job ->
        {:noreply,
         socket
         |> put_flash(:error, "Executing jobs can't be deleted")
         |> assign(:job, job)}
    end
  end

  @impl true
  def handle_info(:refresh, socket) do
    schedule_refresh()

    {:noreply, reload_job(socket)}
  end

  defp reload_job(socket) do
    case Jobs.get_job(socket.assigns.job.id) do
      nil ->
        socket
        |> put_flash(:info, "Job #{socket.assigns.job.id} no longer exists")
        |> push_navigate(to: ~p"/jobs")

      job ->
        assign(socket, :job, job)
    end
  end

  defp schedule_refresh, do: Process.send_after(self(), :refresh, @refresh_interval)
end
