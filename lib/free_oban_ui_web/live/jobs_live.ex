defmodule FreeObanUiWeb.JobsLive do
  use FreeObanUiWeb, :live_view

  alias FreeObanUi.Jobs

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Oban Jobs")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:filters, filters_from_params(params))
     |> assign_jobs()}
  end

  @impl true
  def handle_event("filter", params, socket) do
    {:noreply, push_patch(socket, to: ~p"/?#{filter_query(params)}")}
  end

  def handle_event("refresh", _params, socket) do
    {:noreply, assign_jobs(socket)}
  end

  def handle_event("retry", %{"id" => id}, socket) do
    case Jobs.retry_job(id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Job #{id} queued for retry")
         |> assign_jobs()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not retry job: #{inspect(reason)}")}
    end
  end

  def handle_event("cancel", %{"id" => id}, socket) do
    case Jobs.cancel_job(id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Job #{id} cancelled")
         |> assign_jobs()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not cancel job: #{inspect(reason)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-semibold text-zinc-900">Oban Jobs</h1>
          <p class="mt-1 text-sm text-zinc-600">Inspect recent jobs and retry or cancel them.</p>
        </div>
        <button
          type="button"
          phx-click="refresh"
          class="rounded-lg bg-zinc-900 px-3 py-2 text-sm font-semibold text-white hover:bg-zinc-700"
        >
          Refresh
        </button>
      </div>

      <form phx-change="filter" class="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div>
          <label for="state" class="block text-sm font-medium text-zinc-700">State</label>
          <select
            id="state"
            name="state"
            class="mt-1 block w-full rounded-md border-zinc-300 text-sm"
          >
            <option value="">All</option>
            <option :for={state <- Jobs.states()} value={state} selected={@filters["state"] == state}>
              {state}
            </option>
          </select>
        </div>
        <div>
          <label for="queue" class="block text-sm font-medium text-zinc-700">Queue</label>
          <input
            id="queue"
            type="text"
            name="queue"
            value={@filters["queue"]}
            placeholder="default"
            class="mt-1 block w-full rounded-md border-zinc-300 text-sm"
          />
        </div>
      </form>

      <div class="-mx-4 overflow-x-auto sm:-mx-0">
        <table class="min-w-full divide-y divide-zinc-200 text-sm">
          <thead>
            <tr class="text-left text-zinc-500">
              <th class="px-3 py-2 font-medium">ID</th>
              <th class="px-3 py-2 font-medium">Worker</th>
              <th class="px-3 py-2 font-medium">Queue</th>
              <th class="px-3 py-2 font-medium">State</th>
              <th class="px-3 py-2 font-medium">Attempt</th>
              <th class="px-3 py-2 font-medium">Scheduled</th>
              <th class="px-3 py-2 font-medium">Args</th>
              <th class="px-3 py-2 font-medium">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-zinc-100">
            <tr :if={@jobs == []}>
              <td colspan="8" class="px-3 py-8 text-center text-zinc-500">
                No jobs found.
              </td>
            </tr>
            <tr :for={job <- @jobs} id={"job-#{job.id}"} class="text-zinc-800">
              <td class="whitespace-nowrap px-3 py-2 font-mono">{job.id}</td>
              <td class="px-3 py-2">{job.worker}</td>
              <td class="px-3 py-2">{job.queue}</td>
              <td class="px-3 py-2">
                <span class={["rounded-full px-2 py-0.5 text-xs font-medium", state_class(job.state)]}>
                  {job.state}
                </span>
              </td>
              <td class="px-3 py-2">{job.attempt}/{job.max_attempts}</td>
              <td class="whitespace-nowrap px-3 py-2">{format_datetime(job.scheduled_at)}</td>
              <td class="max-w-xs truncate px-3 py-2 font-mono text-xs">{inspect(job.args)}</td>
              <td class="whitespace-nowrap px-3 py-2">
                <button
                  :if={job.state in ["completed", "discarded", "cancelled"]}
                  type="button"
                  phx-click="retry"
                  phx-value-id={job.id}
                  class="text-sky-700 hover:underline"
                >
                  Retry
                </button>
                <button
                  :if={job.state in ["available", "scheduled", "retryable"]}
                  type="button"
                  phx-click="cancel"
                  phx-value-id={job.id}
                  data-confirm="Cancel this job?"
                  class="text-rose-700 hover:underline"
                >
                  Cancel
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp assign_jobs(socket) do
    assign(socket, :jobs, Jobs.list_jobs(socket.assigns.filters))
  end

  defp filters_from_params(params) do
    %{
      "state" => Map.get(params, "state", ""),
      "queue" => Map.get(params, "queue", "")
    }
  end

  defp filter_query(params) do
    params
    |> Map.take(["state", "queue"])
    |> Enum.reject(fn {_k, v} -> v in [nil, ""] end)
  end

  defp format_datetime(nil), do: "—"

  defp format_datetime(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end

  defp format_datetime(%NaiveDateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end

  defp state_class("completed"), do: "bg-emerald-100 text-emerald-800"
  defp state_class("available"), do: "bg-sky-100 text-sky-800"
  defp state_class("scheduled"), do: "bg-indigo-100 text-indigo-800"
  defp state_class("executing"), do: "bg-amber-100 text-amber-800"
  defp state_class("retryable"), do: "bg-orange-100 text-orange-800"
  defp state_class("cancelled"), do: "bg-zinc-200 text-zinc-700"
  defp state_class("discarded"), do: "bg-rose-100 text-rose-800"
  defp state_class(_), do: "bg-zinc-100 text-zinc-700"
end
