defmodule FreeObanUiWeb.ObanLive.Index do
  use FreeObanUiWeb, :live_view

  alias FreeObanUi.Jobs
  alias FreeObanUi.Workers.ExampleWorker

  @states ~w(all available executing scheduled retryable completed cancelled discarded)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Refresh every 3 seconds for active jobs
      :timer.send_interval(3000, self(), :tick)
    end

    {:ok,
     socket
     |> assign(:page_title, "Oban Jobs")
     |> assign(:selected_job, nil)
     |> assign(:queues, Jobs.list_queues())
     |> assign(:states, @states)
     |> assign(:queue_filter, "all")
     |> assign(:state_filter, "all")
     |> assign(:search_filter, "")
     |> assign(:page, 1)
     |> assign(:page_size, 20)
     |> assign(:sort_by, "id")
     |> assign(:sort_order, "desc")
     |> assign_jobs_data()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    queue_filter = params["queue"] || "all"
    state_filter = params["state"] || "all"
    search_filter = params["search"] || ""
    page = String.to_integer(params["page"] || "1")
    sort_by = params["sort_by"] || "id"
    sort_order = params["sort_order"] || "desc"

    selected_job =
      if job_id = params["job_id"] do
        Jobs.get_job(String.to_integer(job_id))
      else
        nil
      end

    {:noreply,
     socket
     |> assign(:queue_filter, queue_filter)
     |> assign(:state_filter, state_filter)
     |> assign(:search_filter, search_filter)
     |> assign(:page, page)
     |> assign(:sort_by, sort_by)
     |> assign(:sort_order, sort_order)
     |> assign(:selected_job, selected_job)
     |> assign_jobs_data()}
  end

  @impl true
  def handle_info(:tick, socket) do
    {:noreply, assign_jobs_data(socket)}
  end

  @impl true
  def handle_event("filter", %{"queue" => queue, "search" => search}, socket) do
    params = %{
      queue: queue,
      state: socket.assigns.state_filter,
      search: search,
      page: 1,
      sort_by: socket.assigns.sort_by,
      sort_order: socket.assigns.sort_order
    }

    {:noreply, push_patch(socket, to: ~p"/oban?#{params}")}
  end

  @impl true
  def handle_event("select_state", %{"state" => state}, socket) do
    params = %{
      queue: socket.assigns.queue_filter,
      state: state,
      search: socket.assigns.search_filter,
      page: 1,
      sort_by: socket.assigns.sort_by,
      sort_order: socket.assigns.sort_order
    }

    {:noreply, push_patch(socket, to: ~p"/oban?#{params}")}
  end

  @impl true
  def handle_event("sort", %{"by" => by}, socket) do
    sort_order =
      if socket.assigns.sort_by == by && socket.assigns.sort_order == "desc" do
        "asc"
      else
        "desc"
      end

    params = %{
      queue: socket.assigns.queue_filter,
      state: socket.assigns.state_filter,
      search: socket.assigns.search_filter,
      page: socket.assigns.page,
      sort_by: by,
      sort_order: sort_order
    }

    {:noreply, push_patch(socket, to: ~p"/oban?#{params}")}
  end

  @impl true
  def handle_event("page", %{"page" => page}, socket) do
    params = %{
      queue: socket.assigns.queue_filter,
      state: socket.assigns.state_filter,
      search: socket.assigns.search_filter,
      page: page,
      sort_by: socket.assigns.sort_by,
      sort_order: socket.assigns.sort_order
    }

    {:noreply, push_patch(socket, to: ~p"/oban?#{params}")}
  end

  @impl true
  def handle_event("view_job", %{"id" => id}, socket) do
    job = Jobs.get_job(String.to_integer(id))
    {:noreply, assign(socket, :selected_job, job)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :selected_job, nil)}
  end

  @impl true
  def handle_event("retry_job", %{"id" => id}, socket) do
    job_id = String.to_integer(id)
    Jobs.retry_job(job_id)

    {:noreply,
     socket
     |> put_flash(:info, "Job ##{job_id} scheduled for retry.")
     |> assign(:selected_job, Jobs.get_job(job_id))
     |> assign_jobs_data()}
  end

  @impl true
  def handle_event("cancel_job", %{"id" => id}, socket) do
    job_id = String.to_integer(id)
    Jobs.cancel_job(job_id)

    {:noreply,
     socket
     |> put_flash(:info, "Job ##{job_id} cancelled.")
     |> assign(:selected_job, Jobs.get_job(job_id))
     |> assign_jobs_data()}
  end

  @impl true
  def handle_event("delete_job", %{"id" => id}, socket) do
    job_id = String.to_integer(id)
    Jobs.delete_job(job_id)

    {:noreply,
     socket
     |> put_flash(:info, "Job ##{job_id} deleted.")
     |> assign(:selected_job, nil)
     |> assign_jobs_data()}
  end

  @impl true
  def handle_event("retry_all", _params, socket) do
    filters = current_filter_map(socket)
    {:ok, count} = Jobs.retry_all(filters)

    {:noreply,
     socket
     |> put_flash(:info, "Retried #{count} jobs.")
     |> assign_jobs_data()}
  end

  @impl true
  def handle_event("cancel_all", _params, socket) do
    filters = current_filter_map(socket)
    {:ok, count} = Jobs.cancel_all(filters)

    {:noreply,
     socket
     |> put_flash(:info, "Cancelled #{count} jobs.")
     |> assign_jobs_data()}
  end

  @impl true
  def handle_event("enqueue_sample", %{"type" => type}, socket) do
    case type do
      "success" ->
        %{sample: "job_#{System.unique_integer([:positive])}", created_at: DateTime.utc_now()}
        |> ExampleWorker.new(queue: :default)
        |> Oban.insert()

      "failure" ->
        %{action: "fail", sample: "will fail", attempt_time: DateTime.utc_now()}
        |> ExampleWorker.new(queue: :default, max_attempts: 3)
        |> Oban.insert()

      "scheduled" ->
        %{sample: "scheduled_job", run_in: "10m"}
        |> ExampleWorker.new(queue: :events, schedule_in: 600)
        |> Oban.insert()

      _ ->
        :ok
    end

    {:noreply,
     socket
     |> put_flash(:info, "Sample #{type} job enqueued.")
     |> assign_jobs_data()}
  end

  defp current_filter_map(socket) do
    %{}
    |> maybe_put("queue", socket.assigns.queue_filter)
    |> maybe_put("state", socket.assigns.state_filter)
    |> maybe_put("search", socket.assigns.search_filter)
  end

  defp maybe_put(map, _key, "all"), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)

  defp assign_jobs_data(socket) do
    filters = %{
      "queue" => socket.assigns.queue_filter,
      "state" => socket.assigns.state_filter,
      "search" => socket.assigns.search_filter,
      "page" => socket.assigns.page,
      "page_size" => socket.assigns.page_size,
      "sort_by" => socket.assigns.sort_by,
      "sort_order" => socket.assigns.sort_order
    }

    counts = Jobs.count_jobs_by_state(filters)
    total_matching = Jobs.count_jobs(filters)
    jobs = Jobs.list_jobs(filters)
    queues = Jobs.list_queues()

    total_pages = max(1, ceil(total_matching / socket.assigns.page_size))

    socket
    |> assign(:counts, counts)
    |> assign(:total_matching, total_matching)
    |> assign(:total_pages, total_pages)
    |> assign(:jobs, jobs)
    |> assign(:queues, queues)
  end

  defp state_badge_class(state) do
    case state do
      "available" -> "bg-blue-100 text-blue-800 border-blue-200"
      "executing" -> "bg-amber-100 text-amber-800 border-amber-200 animate-pulse"
      "scheduled" -> "bg-purple-100 text-purple-800 border-purple-200"
      "retryable" -> "bg-orange-100 text-orange-800 border-orange-200"
      "completed" -> "bg-emerald-100 text-emerald-800 border-emerald-200"
      "cancelled" -> "bg-zinc-100 text-zinc-700 border-zinc-200"
      "discarded" -> "bg-rose-100 text-rose-800 border-rose-200"
      _ -> "bg-zinc-100 text-zinc-800 border-zinc-200"
    end
  end

  defp format_datetime(nil), do: "-"

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_json(nil), do: "{}"

  defp format_json(data) when is_map(data) or is_list(data) do
    Jason.encode!(data, pretty: true)
  rescue
    _ -> inspect(data)
  end

  defp format_json(other), do: inspect(other)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header Section -->
      <div class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 border-b border-zinc-200 pb-5">
        <div>
          <h1 class="text-2xl font-bold tracking-tight text-zinc-900 flex items-center gap-3">
            <span class="inline-flex items-center justify-center h-9 w-9 rounded-lg bg-indigo-600 text-white font-mono text-lg font-bold">
              O
            </span>
            Oban Dashboard
          </h1>
          <p class="mt-1 text-sm text-zinc-500">
            Monitor, inspect, and manage background jobs and queues.
          </p>
        </div>

        <div class="flex items-center gap-2 flex-wrap">
          <button
            type="button"
            phx-click="enqueue_sample"
            phx-value-type="success"
            class="rounded-md bg-white px-3 py-1.5 text-xs font-semibold text-zinc-700 shadow-sm ring-1 ring-inset ring-zinc-300 hover:bg-zinc-50"
          >
            + Enqueue Sample Job
          </button>
          <button
            type="button"
            phx-click="enqueue_sample"
            phx-value-type="failure"
            class="rounded-md bg-white px-3 py-1.5 text-xs font-semibold text-rose-600 shadow-sm ring-1 ring-inset ring-zinc-300 hover:bg-rose-50"
          >
            + Enqueue Failing Job
          </button>
          <button
            type="button"
            phx-click="enqueue_sample"
            phx-value-type="scheduled"
            class="rounded-md bg-white px-3 py-1.5 text-xs font-semibold text-purple-600 shadow-sm ring-1 ring-inset ring-zinc-300 hover:bg-purple-50"
          >
            + Enqueue Scheduled Job
          </button>
        </div>
      </div>

      <!-- State Stats Overview -->
      <div class="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-8 gap-3">
        <%= for state <- @states do %>
          <% count = Map.get(@counts, state, 0) %>
          <% is_active = @state_filter == state %>
          <button
            type="button"
            phx-click="select_state"
            phx-value-state={state}
            class={[
              "rounded-xl p-3 text-left transition border",
              is_active && "ring-2 ring-indigo-600 border-transparent bg-indigo-50/50 shadow-sm",
              !is_active && "border-zinc-200 bg-white hover:border-zinc-300 hover:bg-zinc-50"
            ]}
          >
            <div class="text-xs font-medium uppercase tracking-wider text-zinc-500">
              <%= state %>
            </div>
            <div class="mt-1 text-xl font-bold text-zinc-900">
              <%= count %>
            </div>
          </button>
        <% end %>
      </div>

      <!-- Filter Controls & Bulk Actions -->
      <div class="bg-white p-4 rounded-xl border border-zinc-200 shadow-sm flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <form phx-change="filter" class="flex flex-wrap items-center gap-3 w-full md:w-auto">
          <div>
            <label for="queue-filter" class="sr-only">Queue</label>
            <select
              id="queue-filter"
              name="queue"
              class="rounded-lg border-zinc-300 text-sm py-1.5 pl-3 pr-8 focus:border-indigo-500 focus:ring-indigo-500"
            >
              <option value="all" selected={@queue_filter == "all"}>All Queues</option>
              <%= for q <- @queues do %>
                <option value={q} selected={@queue_filter == q}>Queue: <%= q %></option>
              <% end %>
            </select>
          </div>

          <div class="relative min-w-[220px]">
            <input
              type="text"
              name="search"
              value={@search_filter}
              placeholder="Search worker or queue..."
              phx-debounce="300"
              class="w-full rounded-lg border-zinc-300 text-sm py-1.5 pl-3 pr-8 focus:border-indigo-500 focus:ring-indigo-500"
            />
          </div>
        </form>

        <div class="flex items-center gap-2 self-end md:self-auto">
          <button
            type="button"
            phx-click="retry_all"
            data-confirm="Are you sure you want to retry all matching jobs?"
            class="rounded-md bg-white px-3 py-1.5 text-xs font-semibold text-amber-700 shadow-sm ring-1 ring-inset ring-amber-300 hover:bg-amber-50"
          >
            Retry All
          </button>
          <button
            type="button"
            phx-click="cancel_all"
            data-confirm="Are you sure you want to cancel all matching jobs?"
            class="rounded-md bg-white px-3 py-1.5 text-xs font-semibold text-rose-700 shadow-sm ring-1 ring-inset ring-rose-300 hover:bg-rose-50"
          >
            Cancel All
          </button>
        </div>
      </div>

      <!-- Jobs Table -->
      <div class="overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm">
        <table class="min-w-full divide-y divide-zinc-200 text-left text-sm">
          <thead class="bg-zinc-50 text-zinc-600 font-medium text-xs uppercase tracking-wider">
            <tr>
              <th scope="col" class="py-3.5 pl-4 pr-3 sm:pl-6 cursor-pointer hover:text-zinc-900" phx-click="sort" phx-value-by="id">
                ID <%= if @sort_by == "id", do: if(@sort_order == "desc", do: "↓", else: "↑") %>
              </th>
              <th scope="col" class="px-3 py-3.5">State</th>
              <th scope="col" class="px-3 py-3.5">Queue</th>
              <th scope="col" class="px-3 py-3.5">Worker</th>
              <th scope="col" class="px-3 py-3.5 cursor-pointer hover:text-zinc-900" phx-click="sort" phx-value-by="attempt">
                Attempt <%= if @sort_by == "attempt", do: if(@sort_order == "desc", do: "↓", else: "↑") %>
              </th>
              <th scope="col" class="px-3 py-3.5 cursor-pointer hover:text-zinc-900" phx-click="sort" phx-value-by="inserted_at">
                Inserted At <%= if @sort_by == "inserted_at", do: if(@sort_order == "desc", do: "↓", else: "↑") %>
              </th>
              <th scope="col" class="px-3 py-3.5 cursor-pointer hover:text-zinc-900" phx-click="sort" phx-value-by="scheduled_at">
                Scheduled At <%= if @sort_by == "scheduled_at", do: if(@sort_order == "desc", do: "↓", else: "↑") %>
              </th>
              <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6 text-right">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-zinc-100 bg-white">
            <%= if Enum.empty?(@jobs) do %>
              <tr>
                <td colspan="8" class="text-center py-12 text-zinc-500">
                  <p class="text-base font-medium">No Oban jobs found</p>
                  <p class="text-sm mt-1">Try selecting a different state or queue filter.</p>
                </td>
              </tr>
            <% else %>
              <%= for job <- @jobs do %>
                <tr class="hover:bg-zinc-50/80 transition-colors">
                  <td class="whitespace-nowrap py-4 pl-4 pr-3 sm:pl-6 font-mono text-xs font-semibold text-indigo-600">
                    <button type="button" phx-click="view_job" phx-value-id={job.id} class="hover:underline">
                      #<%= job.id %>
                    </button>
                  </td>
                  <td class="whitespace-nowrap px-3 py-4">
                    <span class={["inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold border", state_badge_class(job.state)]}>
                      <%= job.state %>
                    </span>
                  </td>
                  <td class="whitespace-nowrap px-3 py-4 font-mono text-xs text-zinc-700">
                    <%= job.queue %>
                  </td>
                  <td class="px-3 py-4 text-xs font-mono text-zinc-900 max-w-[200px] truncate" title={job.worker}>
                    <%= job.worker %>
                  </td>
                  <td class="whitespace-nowrap px-3 py-4 text-xs text-zinc-600">
                    <%= job.attempt %> / <%= job.max_attempts %>
                  </td>
                  <td class="whitespace-nowrap px-3 py-4 text-xs text-zinc-500">
                    <%= format_datetime(job.inserted_at) %>
                  </td>
                  <td class="whitespace-nowrap px-3 py-4 text-xs text-zinc-500">
                    <%= format_datetime(job.scheduled_at) %>
                  </td>
                  <td class="whitespace-nowrap py-4 pl-3 pr-4 sm:pr-6 text-right text-xs font-medium space-x-2">
                    <button
                      type="button"
                      phx-click="view_job"
                      phx-value-id={job.id}
                      class="text-indigo-600 hover:text-indigo-900"
                    >
                      View
                    </button>
                    <%= if job.state in ["retryable", "completed", "cancelled", "discarded"] do %>
                      <button
                        type="button"
                        phx-click="retry_job"
                        phx-value-id={job.id}
                        class="text-amber-600 hover:text-amber-900"
                      >
                        Retry
                      </button>
                    <% end %>
                    <%= if job.state in ["available", "scheduled", "executing", "retryable"] do %>
                      <button
                        type="button"
                        phx-click="cancel_job"
                        phx-value-id={job.id}
                        class="text-rose-600 hover:text-rose-900"
                      >
                        Cancel
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            <% end %>
          </tbody>
        </table>

        <!-- Pagination -->
        <div class="flex items-center justify-between border-t border-zinc-200 bg-zinc-50 px-4 py-3 sm:px-6">
          <div class="text-xs text-zinc-600">
            Showing <span class="font-medium"><%= length(@jobs) %></span> of <span class="font-medium"><%= @total_matching %></span> jobs
          </div>
          <div class="flex items-center gap-2">
            <button
              type="button"
              disabled={@page <= 1}
              phx-click="page"
              phx-value-page={@page - 1}
              class="rounded border border-zinc-300 bg-white px-2.5 py-1 text-xs font-medium text-zinc-700 hover:bg-zinc-50 disabled:opacity-50"
            >
              Previous
            </button>
            <span class="text-xs text-zinc-600">
              Page <%= @page %> of <%= @total_pages %>
            </span>
            <button
              type="button"
              disabled={@page >= @total_pages}
              phx-click="page"
              phx-value-page={@page + 1}
              class="rounded border border-zinc-300 bg-white px-2.5 py-1 text-xs font-medium text-zinc-700 hover:bg-zinc-50 disabled:opacity-50"
            >
              Next
            </button>
          </div>
        </div>
      </div>

      <!-- Job Detail Modal -->
      <%= if @selected_job do %>
        <div class="fixed inset-0 z-50 overflow-y-auto bg-zinc-900/50 backdrop-blur-sm flex items-center justify-center p-4">
          <div class="relative w-full max-w-3xl rounded-2xl bg-white p-6 shadow-2xl border border-zinc-200 max-h-[90vh] overflow-y-auto">
            <div class="flex items-center justify-between border-b border-zinc-100 pb-4">
              <div class="flex items-center gap-3">
                <span class={["inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold border", state_badge_class(@selected_job.state)]}>
                  <%= @selected_job.state %>
                </span>
                <h3 class="text-lg font-bold text-zinc-900 font-mono">
                  Job #<%= @selected_job.id %>
                </h3>
              </div>
              <button
                type="button"
                phx-click="close_modal"
                class="rounded-lg p-1 text-zinc-400 hover:bg-zinc-100 hover:text-zinc-600"
              >
                <.icon name="hero-x-mark" class="h-5 w-5" />
              </button>
            </div>

            <!-- Job Meta Grid -->
            <div class="mt-4 grid grid-cols-2 sm:grid-cols-4 gap-4 bg-zinc-50 p-4 rounded-xl text-xs">
              <div>
                <span class="text-zinc-500 font-medium">Worker</span>
                <p class="font-mono font-semibold text-zinc-900 truncate" title={@selected_job.worker}>
                  <%= @selected_job.worker %>
                </p>
              </div>
              <div>
                <span class="text-zinc-500 font-medium">Queue</span>
                <p class="font-mono font-semibold text-zinc-900">
                  <%= @selected_job.queue %>
                </p>
              </div>
              <div>
                <span class="text-zinc-500 font-medium">Attempt</span>
                <p class="font-mono font-semibold text-zinc-900">
                  <%= @selected_job.attempt %> / <%= @selected_job.max_attempts %>
                </p>
              </div>
              <div>
                <span class="text-zinc-500 font-medium">Priority</span>
                <p class="font-mono font-semibold text-zinc-900">
                  <%= @selected_job.priority %>
                </p>
              </div>
            </div>

            <!-- Timestamp details -->
            <div class="mt-4 grid grid-cols-2 sm:grid-cols-3 gap-3 text-xs border border-zinc-100 p-3 rounded-lg">
              <div>
                <span class="text-zinc-500">Inserted At:</span>
                <p class="font-mono text-zinc-700"><%= format_datetime(@selected_job.inserted_at) %></p>
              </div>
              <div>
                <span class="text-zinc-500">Scheduled At:</span>
                <p class="font-mono text-zinc-700"><%= format_datetime(@selected_job.scheduled_at) %></p>
              </div>
              <div>
                <span class="text-zinc-500">Attempted At:</span>
                <p class="font-mono text-zinc-700"><%= format_datetime(@selected_job.attempted_at) %></p>
              </div>
              <div>
                <span class="text-zinc-500">Completed At:</span>
                <p class="font-mono text-zinc-700"><%= format_datetime(@selected_job.completed_at) %></p>
              </div>
              <div>
                <span class="text-zinc-500">Cancelled At:</span>
                <p class="font-mono text-zinc-700"><%= format_datetime(@selected_job.cancelled_at) %></p>
              </div>
              <div>
                <span class="text-zinc-500">Discarded At:</span>
                <p class="font-mono text-zinc-700"><%= format_datetime(@selected_job.discarded_at) %></p>
              </div>
            </div>

            <!-- Args Section -->
            <div class="mt-5">
              <h4 class="text-xs font-bold uppercase tracking-wider text-zinc-600 mb-1">Arguments (Args)</h4>
              <pre class="bg-zinc-900 text-zinc-100 p-3 rounded-lg text-xs font-mono overflow-x-auto"><%= format_json(@selected_job.args) %></pre>
            </div>

            <!-- Errors Section if any -->
            <%= if not Enum.empty?(@selected_job.errors) do %>
              <div class="mt-5">
                <h4 class="text-xs font-bold uppercase tracking-wider text-rose-600 mb-1">Errors</h4>
                <div class="space-y-2">
                  <%= for err <- @selected_job.errors do %>
                    <pre class="bg-rose-50 border border-rose-200 text-rose-900 p-3 rounded-lg text-xs font-mono overflow-x-auto"><%= format_json(err) %></pre>
                  <% end %>
                </div>
              </div>
            <% end %>

            <!-- Tags Section if any -->
            <%= if not Enum.empty?(@selected_job.tags) do %>
              <div class="mt-4 flex items-center gap-2">
                <span class="text-xs font-medium text-zinc-500">Tags:</span>
                <%= for tag <- @selected_job.tags do %>
                  <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-mono bg-zinc-100 text-zinc-700">
                    <%= tag %>
                  </span>
                <% end %>
              </div>
            <% end %>

            <!-- Modal Action Buttons -->
            <div class="mt-6 flex items-center justify-between border-t border-zinc-100 pt-4">
              <div>
                <button
                  type="button"
                  phx-click="delete_job"
                  phx-value-id={@selected_job.id}
                  data-confirm="Are you sure you want to permanently delete this job?"
                  class="rounded-md bg-rose-50 px-3 py-1.5 text-xs font-semibold text-rose-700 hover:bg-rose-100"
                >
                  Delete Job
                </button>
              </div>
              <div class="flex items-center gap-2">
                <%= if @selected_job.state in ["retryable", "completed", "cancelled", "discarded"] do %>
                  <button
                    type="button"
                    phx-click="retry_job"
                    phx-value-id={@selected_job.id}
                    class="rounded-md bg-amber-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-amber-500 shadow-sm"
                  >
                    Retry Job
                  </button>
                <% end %>
                <%= if @selected_job.state in ["available", "scheduled", "executing", "retryable"] do %>
                  <button
                    type="button"
                    phx-click="cancel_job"
                    phx-value-id={@selected_job.id}
                    class="rounded-md bg-rose-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-rose-500 shadow-sm"
                  >
                    Cancel Job
                  </button>
                <% end %>
                <button
                  type="button"
                  phx-click="close_modal"
                  class="rounded-md bg-zinc-100 px-3 py-1.5 text-xs font-semibold text-zinc-700 hover:bg-zinc-200"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
