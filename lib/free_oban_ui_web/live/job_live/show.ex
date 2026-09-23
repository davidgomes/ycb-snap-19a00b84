defmodule FreeObanUiWeb.JobLive.Show do
  use FreeObanUiWeb, :live_view

  alias FreeObanUi.Jobs

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok, assign(socket, :job, Jobs.get_job!(id))}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :page_title, "Job #{socket.assigns.job.id}")}
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    case Jobs.cancel_job(socket.assigns.job.id) do
      {:ok, job} ->
        {:noreply, socket |> assign(:job, job) |> put_flash(:info, "Job cancelled")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not cancel job: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("retry", _params, socket) do
    case Jobs.retry_job(socket.assigns.job.id) do
      {:ok, job} ->
        {:noreply, socket |> assign(:job, job) |> put_flash(:info, "Job queued for retry")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not retry job: #{inspect(reason)}")}
    end
  end
end
