defmodule FreeObanUiWeb.JobLive.Index do
  use FreeObanUiWeb, :live_view

  alias FreeObanUi.Jobs

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :jobs, [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = %{
      "state" => params["state"] || "",
      "queue" => params["queue"] || ""
    }

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:jobs, Jobs.list_jobs(filters))
     |> assign(:page_title, "Jobs")}
  end

  @impl true
  def handle_event("filter", params, socket) do
    {:noreply, push_patch(socket, to: ~p"/jobs?#{filter_params(params)}")}
  end

  @impl true
  def handle_event("cancel", %{"id" => id}, socket) do
    case Jobs.cancel_job(id) do
      {:ok, _job} ->
        {:noreply, reload(socket, "Job cancelled")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not cancel job: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("retry", %{"id" => id}, socket) do
    case Jobs.retry_job(id) do
      {:ok, _job} ->
        {:noreply, reload(socket, "Job queued for retry")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not retry job: #{inspect(reason)}")}
    end
  end

  defp reload(socket, message) do
    socket
    |> assign(:jobs, Jobs.list_jobs(socket.assigns.filters))
    |> put_flash(:info, message)
  end

  defp filter_params(params) do
    params
    |> Map.take(["state", "queue"])
    |> Enum.reject(fn {_k, v} -> v in [nil, ""] end)
  end
end
