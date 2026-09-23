defmodule FreeObanUiWeb.JobLive.Show do
  use FreeObanUiWeb, :live_view

  import FreeObanUiWeb.JobComponents

  alias FreeObanUi.Jobs

  @refresh_interval :timer.seconds(2)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    job = Jobs.get_job!(id)

    if connected?(socket), do: schedule_refresh()

    {:ok, assign(socket, job: job, page_title: "Job #{job.id}")}
  end

  @impl true
  def handle_event("retry", _params, socket) do
    :ok = Jobs.retry_job(socket.assigns.job)

    {:noreply, socket |> put_flash(:info, "Job will be retried") |> reload_job()}
  end

  def handle_event("cancel", _params, socket) do
    :ok = Jobs.cancel_job(socket.assigns.job)

    {:noreply, socket |> put_flash(:info, "Job cancelled") |> reload_job()}
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
        |> put_flash(:error, "Job #{socket.assigns.job.id} no longer exists")
        |> push_navigate(to: ~p"/jobs")

      job ->
        assign(socket, :job, job)
    end
  end

  defp schedule_refresh, do: Process.send_after(self(), :refresh, @refresh_interval)

  defp error_time(%{"at" => at}) when is_binary(at) do
    case DateTime.from_iso8601(at) do
      {:ok, datetime, _offset} -> datetime
      {:error, _reason} -> nil
    end
  end

  defp error_time(_error), do: nil

  defp join_or_dash([_ | _] = values), do: Enum.join(values, ", ")
  defp join_or_dash(_empty), do: "—"
end
