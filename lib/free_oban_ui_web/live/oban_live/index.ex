defmodule FreeObanUiWeb.ObanLive.Index do
  use FreeObanUiWeb, :live_view

  alias FreeObanUi.Jobs

  @refresh_interval :timer.seconds(2)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(@refresh_interval, self(), :refresh)

    {:ok,
     socket
     |> assign(:page_title, "Oban Jobs")
     |> assign(:state_filter, "all")
     |> assign(:queue_filter, "all")
     |> assign(:page, 1)
     |> load_jobs()}
  end

  @impl true
  def handle_event("filter", params, socket) do
    {:noreply,
     socket
     |> assign(:state_filter, Map.get(params, "state", "all"))
     |> assign(:queue_filter, Map.get(params, "queue", "all"))
     |> assign(:page, 1)
     |> load_jobs()}
  end

  def handle_event("prev_page", _params, socket) do
    {:noreply, socket |> assign(:page, max(socket.assigns.page - 1, 1)) |> load_jobs()}
  end

  def handle_event("next_page", _params, socket) do
    {:noreply, socket |> assign(:page, socket.assigns.page + 1) |> load_jobs()}
  end

  def handle_event("cancel_job", %{"id" => id}, socket) do
    id |> String.to_integer() |> Jobs.cancel_job()
    {:noreply, load_jobs(socket)}
  end

  def handle_event("retry_job", %{"id" => id}, socket) do
    id |> String.to_integer() |> Jobs.retry_job()
    {:noreply, load_jobs(socket)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, load_jobs(socket)}
  end

  defp load_jobs(socket) do
    filters = %{state: socket.assigns.state_filter, queue: socket.assigns.queue_filter}
    total_count = Jobs.count_jobs(filters)
    total_pages = max(ceil(total_count / Jobs.page_size()), 1)
    page = min(socket.assigns.page, total_pages)

    assign(socket,
      jobs: Jobs.list_jobs(filters, page: page),
      total_count: total_count,
      total_pages: total_pages,
      page: page,
      queues: Jobs.queues()
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Oban Jobs
      <:subtitle>
        <%= @total_count %> job(s) matching the current filters. Refreshes automatically.
      </:subtitle>
    </.header>

    <form phx-change="filter" phx-submit="filter" class="mt-6 flex flex-wrap items-end gap-4">
      <div>
        <.label for="state">State</.label>
        <select id="state" name="state" class="mt-2 block w-40 rounded-md border border-gray-300 bg-white shadow-sm focus:border-zinc-400 focus:ring-0 sm:text-sm">
          <option value="all" selected={@state_filter == "all"}>All states</option>
          <option :for={state <- Jobs.states()} value={state} selected={@state_filter == state}>
            <%= String.capitalize(state) %>
          </option>
        </select>
      </div>
      <div>
        <.label for="queue">Queue</.label>
        <select id="queue" name="queue" class="mt-2 block w-40 rounded-md border border-gray-300 bg-white shadow-sm focus:border-zinc-400 focus:ring-0 sm:text-sm">
          <option value="all" selected={@queue_filter == "all"}>All queues</option>
          <option :for={queue <- @queues} value={queue} selected={@queue_filter == queue}>
            <%= queue %>
          </option>
        </select>
      </div>
    </form>

    <.table id="oban-jobs" rows={@jobs} row_id={fn job -> "job-#{job.id}" end}>
      <:col :let={job} label="ID"><%= job.id %></:col>
      <:col :let={job} label="State">
        <span class={["rounded-full px-2 py-1 text-xs font-semibold", state_classes(job.state)]}>
          <%= job.state %>
        </span>
      </:col>
      <:col :let={job} label="Queue"><%= job.queue %></:col>
      <:col :let={job} label="Worker"><%= job.worker %></:col>
      <:col :let={job} label="Args">
        <code class="text-xs"><%= truncate(inspect(job.args)) %></code>
      </:col>
      <:col :let={job} label="Attempt"><%= job.attempt %>/<%= job.max_attempts %></:col>
      <:col :let={job} label="Inserted at"><%= format_time(job.inserted_at) %></:col>
      <:col :let={job} label="Scheduled at"><%= format_time(job.scheduled_at) %></:col>
      <:action :let={job}>
        <button
          :if={job.state in ~w(available scheduled executing retryable)}
          type="button"
          phx-click="cancel_job"
          phx-value-id={job.id}
          data-confirm="Cancel this job?"
          class="text-rose-600 hover:text-rose-700"
        >
          Cancel
        </button>
        <button
          :if={job.state in ~w(cancelled discarded retryable)}
          type="button"
          phx-click="retry_job"
          phx-value-id={job.id}
          class="text-emerald-600 hover:text-emerald-700"
        >
          Retry
        </button>
      </:action>
    </.table>

    <div class="mt-6 flex items-center justify-between text-sm text-zinc-600">
      <span>Page <%= @page %> of <%= @total_pages %></span>
      <div class="flex gap-2">
        <.button type="button" phx-click="prev_page" disabled={@page <= 1}>Previous</.button>
        <.button type="button" phx-click="next_page" disabled={@page >= @total_pages}>Next</.button>
      </div>
    </div>
    """
  end

  defp state_classes("executing"), do: "bg-blue-50 text-blue-700"
  defp state_classes("available"), do: "bg-zinc-100 text-zinc-700"
  defp state_classes("scheduled"), do: "bg-indigo-50 text-indigo-700"
  defp state_classes("retryable"), do: "bg-amber-50 text-amber-700"
  defp state_classes("completed"), do: "bg-emerald-50 text-emerald-700"
  defp state_classes("cancelled"), do: "bg-zinc-100 text-zinc-500"
  defp state_classes("discarded"), do: "bg-rose-50 text-rose-700"
  defp state_classes(_), do: "bg-zinc-100 text-zinc-700"

  defp format_time(nil), do: "-"
  defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")

  defp truncate(string) when byte_size(string) > 60, do: "#{binary_part(string, 0, 60)}…"
  defp truncate(string), do: string
end
