defmodule FreeObanUiWeb.JobLive.Index do
  use FreeObanUiWeb, :live_view

  import FreeObanUiWeb.JobLive.Components

  alias FreeObanUi.Jobs

  @refresh_interval :timer.seconds(2)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: schedule_refresh()

    {:ok, assign(socket, page_title: "Jobs")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket =
      socket
      |> assign(:state, blank_to_nil(params["state"]))
      |> assign(:queue, blank_to_nil(params["queue"]))
      |> load_jobs()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_queue", %{"queue" => queue}, socket) do
    {:noreply, push_patch(socket, to: jobs_path(socket.assigns.state, blank_to_nil(queue)))}
  end

  @impl true
  def handle_info(:refresh, socket) do
    schedule_refresh()
    {:noreply, load_jobs(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Jobs
      <:subtitle>Inspect Oban jobs by state and queue.</:subtitle>
    </.header>

    <nav class="mt-8 flex flex-wrap gap-2 text-sm" id="state-filters">
      <.link
        patch={jobs_path(nil, @queue)}
        class={state_link_class(is_nil(@state))}
        id="state-filter-all"
      >
        All <span class="ml-1 text-zinc-500"><%= total(@counts) %></span>
      </.link>
      <.link
        :for={state <- Jobs.states()}
        patch={jobs_path(state, @queue)}
        class={state_link_class(@state == state)}
        id={"state-filter-#{state}"}
      >
        <%= String.capitalize(state) %>
        <span class="ml-1 text-zinc-500"><%= @counts[state] %></span>
      </.link>
    </nav>

    <form id="queue-filter" phx-change="filter_queue" class="mt-4">
      <.input
        type="select"
        name="queue"
        label="Queue"
        value={@queue}
        prompt="All queues"
        options={@queues}
      />
    </form>

    <.table
      id="jobs"
      rows={@jobs}
      row_id={fn job -> "jobs-#{job.id}" end}
      row_click={fn job -> JS.navigate(~p"/jobs/#{job.id}") end}
    >
      <:col :let={job} label="ID"><%= job.id %></:col>
      <:col :let={job} label="Worker"><%= job.worker %></:col>
      <:col :let={job} label="Queue"><%= job.queue %></:col>
      <:col :let={job} label="State"><.state_badge state={job.state} /></:col>
      <:col :let={job} label="Attempt"><%= job.attempt %>/<%= job.max_attempts %></:col>
      <:col :let={job} label="Inserted"><.timestamp at={job.inserted_at} /></:col>
    </.table>

    <p :if={@jobs == []} id="jobs-empty" class="mt-6 text-sm text-zinc-500">
      No jobs found.
    </p>
    """
  end

  defp load_jobs(socket) do
    %{state: state, queue: queue} = socket.assigns

    assign(socket,
      jobs: Jobs.list_jobs(state: state, queue: queue),
      counts: Jobs.count_by_state(),
      queues: Jobs.list_queues()
    )
  end

  defp schedule_refresh, do: Process.send_after(self(), :refresh, @refresh_interval)

  defp jobs_path(state, queue) do
    query = Enum.reject([state: state, queue: queue], fn {_key, value} -> is_nil(value) end)
    ~p"/jobs?#{query}"
  end

  defp total(counts), do: counts |> Map.values() |> Enum.sum()

  defp state_link_class(true),
    do: "rounded-full bg-zinc-900 px-3 py-1 font-semibold text-white"

  defp state_link_class(false),
    do: "rounded-full bg-zinc-100 px-3 py-1 font-semibold text-zinc-700 hover:bg-zinc-200"

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value
end
