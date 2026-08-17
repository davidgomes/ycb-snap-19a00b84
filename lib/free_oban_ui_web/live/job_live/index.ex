defmodule FreeObanUiWeb.JobLive.Index do
  use FreeObanUiWeb, :live_view

  alias FreeObanUi.Jobs

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Oban Jobs")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply,
     socket
     |> assign(:state, params["state"])
     |> assign(:queue, params["queue"])
     |> assign(:jobs, Jobs.list_jobs(params))}
  end

  @impl true
  def handle_event("filter", params, socket) do
    query =
      params
      |> Map.take(["state", "queue"])
      |> Enum.reject(fn {_k, v} -> v in [nil, ""] end)
      |> Map.new()

    {:noreply, push_patch(socket, to: ~p"/jobs?#{query}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Oban Jobs
        <:subtitle>Recent jobs from the Oban queue</:subtitle>
      </.header>

      <form phx-change="filter" class="mt-6 flex flex-wrap items-end gap-4">
        <div>
          <label for="state" class="block text-sm font-semibold text-zinc-800">State</label>
          <select
            id="state"
            name="state"
            class="mt-2 block rounded-lg border border-zinc-300 bg-white px-3 py-2 text-sm"
          >
            <option value="">All</option>
            <option :for={state <- Jobs.states()} value={state} selected={@state == state}>
              <%= state %>
            </option>
          </select>
        </div>
        <div>
          <label for="queue" class="block text-sm font-semibold text-zinc-800">Queue</label>
          <input
            id="queue"
            name="queue"
            type="text"
            value={@queue}
            placeholder="default"
            class="mt-2 block rounded-lg border border-zinc-300 px-3 py-2 text-sm"
          />
        </div>
      </form>

      <.table
        id="jobs"
        rows={@jobs}
        row_click={fn job -> JS.navigate(~p"/jobs/#{job}") end}
        row_id={fn job -> "job-#{job.id}" end}
      >
        <:col :let={job} label="ID"><%= job.id %></:col>
        <:col :let={job} label="Worker"><%= job.worker %></:col>
        <:col :let={job} label="Queue"><%= job.queue %></:col>
        <:col :let={job} label="State"><%= job.state %></:col>
        <:col :let={job} label="Attempt"><%= job.attempt %>/<%= job.max_attempts %></:col>
        <:col :let={job} label="Inserted"><%= format_time(job.inserted_at) %></:col>
      </.table>

      <p :if={@jobs == []} class="mt-8 text-sm text-zinc-500">No jobs found.</p>
    </div>
    """
  end

  defp format_time(nil), do: "—"
  defp format_time(datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
end
