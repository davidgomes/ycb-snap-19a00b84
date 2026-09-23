defmodule FreeObanUiWeb.JobLive.Show do
  use FreeObanUiWeb, :live_view

  import FreeObanUiWeb.JobLive.Components

  alias FreeObanUi.Jobs

  @refresh_interval :timer.seconds(2)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    job = Jobs.get_job!(id)

    if connected?(socket), do: schedule_refresh()

    {:ok, assign(socket, job: job, now: DateTime.utc_now(), page_title: "Job ##{job.id}")}
  end

  @impl true
  def handle_event(action, %{"id" => id}, socket) when action in ~w(retry cancel delete) do
    case apply_action(socket, action, id) do
      {:ok, socket} when action == "delete" -> {:noreply, push_navigate(socket, to: ~p"/jobs")}
      {_result, socket} -> {:noreply, reload_job(socket)}
    end
  end

  @impl true
  def handle_info(:refresh, socket) do
    schedule_refresh()

    {:noreply, reload_job(socket)}
  end

  defp schedule_refresh, do: Process.send_after(self(), :refresh, @refresh_interval)

  defp reload_job(socket) do
    %{job: %{id: id}} = socket.assigns

    case Jobs.get_job(id) do
      nil ->
        socket
        |> put_flash(:error, "Job ##{id} no longer exists")
        |> push_navigate(to: ~p"/jobs")

      job ->
        assign(socket, job: job, now: DateTime.utc_now())
    end
  end

  defp to_json(term), do: Jason.encode!(term, pretty: true)
end
