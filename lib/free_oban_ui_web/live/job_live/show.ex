defmodule FreeObanUiWeb.JobLive.Show do
  use FreeObanUiWeb, :live_view

  import FreeObanUiWeb.JobComponents

  alias FreeObanUi.Jobs

  @refresh_interval :timer.seconds(2)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    job = Jobs.get_job!(id)

    if connected?(socket), do: :timer.send_interval(@refresh_interval, self(), :refresh)

    {:ok,
     socket
     |> assign(:page_title, "Job #{job.id}")
     |> assign(:job, job)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, reload_job(socket)}
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
    {:ok, _job} = Jobs.delete_job(socket.assigns.job)

    {:noreply,
     socket
     |> put_flash(:info, "Job deleted")
     |> push_navigate(to: ~p"/jobs")}
  end

  defp reload_job(socket) do
    case Jobs.get_job(socket.assigns.job.id) do
      nil ->
        socket
        |> put_flash(:error, "Job no longer exists")
        |> push_navigate(to: ~p"/jobs")

      job ->
        assign(socket, :job, job)
    end
  end

  defp format_json(term), do: Jason.encode!(term, pretty: true)
end
