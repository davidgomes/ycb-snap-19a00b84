defmodule FreeObanUiWeb.JobLive.Show do
  use FreeObanUiWeb, :live_view

  alias FreeObanUi.Jobs

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Job #{id}")
     |> assign(:job, Jobs.get_job!(id)), layout: {FreeObanUiWeb.Layouts, :wide}}
  end

  @impl true
  def handle_event("retry", _params, socket) do
    case Jobs.retry_job(socket.assigns.job) do
      :ok ->
        {:noreply, reload_job(socket, "Job scheduled to retry")}

      {:ok, job} ->
        {:noreply,
         socket
         |> put_flash(:info, "Job scheduled to retry")
         |> assign(:job, job)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not retry job: #{inspect(reason)}")}
    end
  end

  def handle_event("cancel", _params, socket) do
    case Jobs.cancel_job(socket.assigns.job) do
      :ok ->
        {:noreply, reload_job(socket, "Job cancelled")}

      {:ok, job} ->
        {:noreply,
         socket
         |> put_flash(:info, "Job cancelled")
         |> assign(:job, job)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not cancel job: #{inspect(reason)}")}
    end
  end

  defp reload_job(socket, message) do
    socket
    |> put_flash(:info, message)
    |> assign(:job, Jobs.get_job!(socket.assigns.job.id))
  end
end
