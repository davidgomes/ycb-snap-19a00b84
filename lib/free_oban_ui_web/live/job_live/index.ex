defmodule FreeObanUiWeb.JobLive.Index do
  use FreeObanUiWeb, :live_view

  import FreeObanUiWeb.JobLive.Components

  alias FreeObanUi.Jobs

  @refresh_interval :timer.seconds(2)

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Jobs
      <:subtitle>Showing the <%= length(@jobs) %> most recent matching jobs.</:subtitle>
    </.header>

    <nav id="state-tabs" class="mt-6 flex flex-wrap gap-2 text-sm">
      <.link
        :for={{state, label, count} <- state_tabs(@counts)}
        patch={jobs_path(%{@filters | "state" => state})}
        class={[
          "rounded-lg px-3 py-1 font-medium",
          @filters["state"] == state && "bg-zinc-900 text-white",
          @filters["state"] != state && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
        ]}
      >
        <%= label %> <span class="ml-1 opacity-70"><%= count %></span>
      </.link>
    </nav>

    <form id="job-filters" phx-change="filter" phx-submit="filter" class="mt-4 flex gap-4">
      <div class="w-48">
        <.input
          type="select"
          id="filter-queue"
          name="filters[queue]"
          value={@filters["queue"]}
          options={@queues}
          prompt="All queues"
        />
      </div>
      <div class="flex-1">
        <.input
          type="text"
          id="filter-search"
          name="filters[search]"
          value={@filters["search"]}
          placeholder="Search by worker"
          phx-debounce="300"
        />
      </div>
    </form>

    <.table
      id="jobs"
      rows={@jobs}
      row_id={&"job-#{&1.id}"}
      row_click={&JS.navigate(~p"/jobs/#{&1.id}")}
    >
      <:col :let={job} label="ID"><%= job.id %></:col>
      <:col :let={job} label="Worker"><%= job.worker %></:col>
      <:col :let={job} label="Queue"><%= job.queue %></:col>
      <:col :let={job} label="State"><.state_badge state={job.state} /></:col>
      <:col :let={job} label="Attempt"><%= job.attempt %>/<%= job.max_attempts %></:col>
      <:col :let={job} label="Args">
        <code class="block max-w-xs truncate text-xs"><%= Jason.encode!(job.args) %></code>
      </:col>
      <:col :let={job} label="When">
        <span title={absolute_time(state_time(job))}><%= relative_time(state_time(job)) %></span>
      </:col>
    </.table>

    <p :if={@jobs == []} id="jobs-empty" class="mt-8 text-center text-sm text-zinc-500">
      No jobs found.
    </p>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(@refresh_interval, self(), :refresh)

    {:ok, assign(socket, :page_title, "Jobs")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = Map.new(~w(state queue search), &{&1, Map.get(params, &1, "")})

    {:noreply, socket |> assign(:filters, filters) |> load_jobs()}
  end

  @impl true
  def handle_event("filter", %{"filters" => params}, socket) do
    filters = Map.merge(socket.assigns.filters, Map.take(params, ~w(queue search)))

    {:noreply, push_patch(socket, to: jobs_path(filters))}
  end

  @impl true
  def handle_info(:refresh, socket), do: {:noreply, load_jobs(socket)}

  defp load_jobs(socket) do
    %{"state" => state, "queue" => queue, "search" => search} = socket.assigns.filters

    socket
    |> assign(:counts, Jobs.count_by_state(queue: queue, search: search))
    |> assign(:queues, Jobs.list_queues())
    |> assign(:jobs, Jobs.list_jobs(state: state, queue: queue, search: search))
  end

  defp state_tabs(counts) do
    all = {"", "All", counts |> Map.values() |> Enum.sum()}

    [all | Enum.map(Jobs.states(), &{&1, String.capitalize(&1), counts[&1]})]
  end

  defp jobs_path(filters) do
    params = for {key, value} <- filters, value != "", into: %{}, do: {key, value}

    ~p"/jobs?#{params}"
  end
end
