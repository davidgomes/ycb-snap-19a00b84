defmodule FreeObanUiWeb.JobLive.Index do
  use FreeObanUiWeb, :live_view

  alias FreeObanUi.Jobs

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, queues: Jobs.list_queues())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    state = params["state"] || ""
    queue = params["queue"] || ""

    socket =
      socket
      |> assign(state: state, queue: queue)
      |> assign(counts: Jobs.count_by_state())
      |> assign(jobs: Jobs.list_jobs(%{state: state, queue: queue}))

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", %{"state" => state, "queue" => queue}, socket) do
    {:noreply, push_patch(socket, to: ~p"/jobs?#{%{state: state, queue: queue}}")}
  end

  def handle_event("refresh", _params, socket) do
    socket =
      socket
      |> assign(counts: Jobs.count_by_state())
      |> assign(jobs: Jobs.list_jobs(%{state: socket.assigns.state, queue: socket.assigns.queue}))

    {:noreply, socket}
  end

  def handle_event("retry", %{"id" => id}, socket) do
    id
    |> String.to_integer()
    |> Jobs.get_job!()
    |> Jobs.retry_job()

    {:noreply, socket |> put_flash(:info, "Job scheduled for retry.") |> reload_jobs()}
  end

  def handle_event("cancel", %{"id" => id}, socket) do
    id
    |> String.to_integer()
    |> Jobs.get_job!()
    |> Jobs.cancel_job()

    {:noreply, socket |> put_flash(:info, "Job cancelled.") |> reload_jobs()}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    id
    |> String.to_integer()
    |> Jobs.get_job!()
    |> Jobs.delete_job()

    {:noreply, socket |> put_flash(:info, "Job deleted.") |> reload_jobs()}
  end

  defp reload_jobs(socket) do
    socket
    |> assign(counts: Jobs.count_by_state())
    |> assign(jobs: Jobs.list_jobs(%{state: socket.assigns.state, queue: socket.assigns.queue}))
  end

  defp state_badge_class("executing"), do: "bg-blue-100 text-blue-800"
  defp state_badge_class("available"), do: "bg-amber-100 text-amber-800"
  defp state_badge_class("scheduled"), do: "bg-indigo-100 text-indigo-800"
  defp state_badge_class("retryable"), do: "bg-orange-100 text-orange-800"
  defp state_badge_class("completed"), do: "bg-emerald-100 text-emerald-800"
  defp state_badge_class("discarded"), do: "bg-rose-100 text-rose-800"
  defp state_badge_class("cancelled"), do: "bg-zinc-200 text-zinc-700"
  defp state_badge_class(_), do: "bg-zinc-100 text-zinc-700"

  defp format_time(nil), do: "-"

  defp format_time(%DateTime{} = dt),
    do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Oban Jobs
      <:subtitle>Inspect and manage background jobs across all queues.</:subtitle>
      <:actions>
        <.button phx-click="refresh">Refresh</.button>
      </:actions>
    </.header>

    <form phx-change="filter" class="mt-6 flex flex-wrap items-end gap-4">
      <div>
        <.label for="state">State</.label>
        <select
          id="state"
          name="state"
          class="mt-2 block w-48 rounded-md border border-gray-300 bg-white shadow-sm focus:border-zinc-400 focus:ring-0 sm:text-sm"
        >
          <option value="" selected={@state == ""}>All states</option>
          <option :for={s <- Jobs.states()} value={s} selected={@state == s}>
            <%= s %> (<%= Map.get(@counts, s, 0) %>)
          </option>
        </select>
      </div>
      <div>
        <.label for="queue">Queue</.label>
        <select
          id="queue"
          name="queue"
          class="mt-2 block w-48 rounded-md border border-gray-300 bg-white shadow-sm focus:border-zinc-400 focus:ring-0 sm:text-sm"
        >
          <option value="" selected={@queue == ""}>All queues</option>
          <option :for={q <- @queues} value={q} selected={@queue == q}><%= q %></option>
        </select>
      </div>
    </form>

    <.table id="jobs" rows={@jobs}>
      <:col :let={job} label="ID"><%= job.id %></:col>
      <:col :let={job} label="Worker"><%= job.worker %></:col>
      <:col :let={job} label="Queue"><%= job.queue %></:col>
      <:col :let={job} label="State">
        <span class={["rounded-full px-2 py-1 text-xs font-semibold", state_badge_class(job.state)]}>
          <%= job.state %>
        </span>
      </:col>
      <:col :let={job} label="Attempts"><%= job.attempt %>/<%= job.max_attempts %></:col>
      <:col :let={job} label="Inserted at"><%= format_time(job.inserted_at) %></:col>
      <:col :let={job} label="Scheduled at"><%= format_time(job.scheduled_at) %></:col>
      <:action :let={job}>
        <button
          :if={job.state in ~w(retryable discarded cancelled completed)}
          type="button"
          phx-click="retry"
          phx-value-id={job.id}
          data-confirm="Retry this job?"
        >
          Retry
        </button>
        <button
          :if={job.state in ~w(available scheduled executing retryable)}
          type="button"
          phx-click="cancel"
          phx-value-id={job.id}
          data-confirm="Cancel this job?"
        >
          Cancel
        </button>
        <button
          type="button"
          phx-click="delete"
          phx-value-id={job.id}
          data-confirm="Delete this job permanently?"
        >
          Delete
        </button>
      </:action>
    </.table>

    <p :if={@jobs == []} class="mt-6 text-sm text-zinc-500">No jobs found for these filters.</p>
    """
  end
end
