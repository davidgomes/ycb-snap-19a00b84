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
  def handle_params(params, _uri, socket) do
    state = Map.get(params, "state", socket.assigns[:state_filter] || "all")
    queue = Map.get(params, "queue", socket.assigns[:queue_filter] || "all")
    page = params |> Map.get("page", "1") |> String.to_integer() |> max(1)

    {:noreply,
     socket
     |> assign(:state_filter, state)
     |> assign(:queue_filter, queue)
     |> assign(:page, page)
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

    {:noreply,
     socket
     |> put_flash(:info, "Job cancelled.")
     |> load_jobs()}
  end

  def handle_event("retry_job", %{"id" => id}, socket) do
    id |> String.to_integer() |> Jobs.retry_job()

    {:noreply,
     socket
     |> put_flash(:info, "Job scheduled for retry.")
     |> load_jobs()}
  end

  def handle_event("delete_job", %{"id" => id}, socket) do
    id |> String.to_integer() |> Jobs.delete_job()

    {:noreply,
     socket
     |> put_flash(:info, "Job deleted.")
     |> load_jobs()}
  end

  # Aliases for actions if invoked with "cancel", "retry", "delete"
  def handle_event("cancel", %{"id" => id}, socket), do: handle_event("cancel_job", %{"id" => id}, socket)
  def handle_event("retry", %{"id" => id}, socket), do: handle_event("retry_job", %{"id" => id}, socket)
  def handle_event("delete", %{"id" => id}, socket), do: handle_event("delete_job", %{"id" => id}, socket)

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
      queues: Jobs.queues(),
      state_counts: Jobs.count_by_state()
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Oban Jobs
      <:subtitle>
        <%= @total_count %> job(s) matching current filter. Refreshes automatically.
      </:subtitle>
    </.header>

    <div class="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-4 lg:grid-cols-7">
      <div :for={state <- Jobs.states()} class="rounded-lg border border-zinc-200 bg-zinc-50 p-3 text-center">
        <div class="text-xs font-semibold text-zinc-500 uppercase"><%= state %></div>
        <div class="mt-1 text-lg font-bold text-zinc-900"><%= @state_counts[state] || 0 %></div>
      </div>
    </div>

    <form phx-change="filter" phx-submit="filter" class="mt-6 flex flex-wrap items-end gap-4">
      <div>
        <.label for="state">State</.label>
        <select id="state" name="state" class="mt-2 block w-40 rounded-md border border-gray-300 bg-white shadow-sm focus:border-zinc-400 focus:ring-0 sm:text-sm">
          <option value="all" selected={@state_filter in ["all", "", nil]}>All states</option>
          <option :for={state <- Jobs.states()} value={state} selected={@state_filter == state}>
            <%= String.capitalize(state) %> (<%= @state_counts[state] || 0 %>)
          </option>
        </select>
      </div>
      <div>
        <.label for="queue">Queue</.label>
        <select id="queue" name="queue" class="mt-2 block w-40 rounded-md border border-gray-300 bg-white shadow-sm focus:border-zinc-400 focus:ring-0 sm:text-sm">
          <option value="all" selected={@queue_filter in ["all", "", nil]}>All queues</option>
          <option :for={queue <- @queues} value={queue} selected={@queue_filter == queue}>
            <%= queue %>
          </option>
        </select>
      </div>
    </form>

    <div id="jobs" class="mt-6">
      <%= if Enum.empty?(@jobs) do %>
        <div class="rounded-lg border border-dashed border-zinc-300 p-8 text-center text-zinc-500">
          No jobs found.
        </div>
      <% else %>
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
              phx-click="cancel"
              phx-value-id={job.id}
              data-confirm="Cancel this job?"
              class="text-rose-600 hover:text-rose-700 text-xs font-medium mr-2"
            >
              Cancel
            </button>
            <button
              :if={job.state in ~w(cancelled discarded retryable)}
              type="button"
              phx-click="retry"
              phx-value-id={job.id}
              class="text-emerald-600 hover:text-emerald-700 text-xs font-medium mr-2"
            >
              Retry
            </button>
            <button
              type="button"
              phx-click="delete"
              phx-value-id={job.id}
              data-confirm="Delete this job?"
              class="text-zinc-500 hover:text-zinc-700 text-xs font-medium"
            >
              Delete
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
      <% end %>
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
  defp format_time(%NaiveDateTime{} = ndt), do: Calendar.strftime(ndt, "%Y-%m-%d %H:%M:%S")

  defp truncate(string) when byte_size(string) > 60, do: "#{binary_part(string, 0, 60)}…"
  defp truncate(string), do: string
end
