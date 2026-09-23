defmodule FreeObanUiWeb.JobLive.Index do
  use FreeObanUiWeb, :live_view

  alias FreeObanUi.Jobs

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket, layout: {FreeObanUiWeb.Layouts, :wide}}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    state = params["state"]

    {:noreply,
     socket
     |> assign(:page_title, "Oban Jobs")
     |> assign(:state, state)
     |> assign(:jobs, Jobs.list_jobs(state: state))}
  end

  @impl true
  def handle_event("retry", %{"id" => id}, socket) do
    job = Jobs.get_job!(id)

    case Jobs.retry_job(job) do
      :ok ->
        {:noreply, refresh(socket, "Job scheduled to retry")}

      {:ok, _} ->
        {:noreply, refresh(socket, "Job scheduled to retry")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not retry job: #{inspect(reason)}")}
    end
  end

  def handle_event("cancel", %{"id" => id}, socket) do
    job = Jobs.get_job!(id)

    case Jobs.cancel_job(job) do
      :ok ->
        {:noreply, refresh(socket, "Job cancelled")}

      {:ok, _} ->
        {:noreply, refresh(socket, "Job cancelled")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not cancel job: #{inspect(reason)}")}
    end
  end

  defp refresh(socket, message) do
    socket
    |> put_flash(:info, message)
    |> assign(:jobs, Jobs.list_jobs(state: socket.assigns.state))
  end

  defp state_class("completed"), do: "bg-emerald-100 text-emerald-800"
  defp state_class("executing"), do: "bg-sky-100 text-sky-800"
  defp state_class("available"), do: "bg-zinc-100 text-zinc-800"
  defp state_class("scheduled"), do: "bg-indigo-100 text-indigo-800"
  defp state_class("retryable"), do: "bg-amber-100 text-amber-800"
  defp state_class("discarded"), do: "bg-rose-100 text-rose-800"
  defp state_class("cancelled"), do: "bg-orange-100 text-orange-800"
  defp state_class(_), do: "bg-zinc-100 text-zinc-800"
end
