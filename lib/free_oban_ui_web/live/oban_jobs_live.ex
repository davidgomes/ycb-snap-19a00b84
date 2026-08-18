defmodule FreeObanUiWeb.ObanJobsLive do
  @moduledoc """
  A minimal LiveView UI for inspecting and managing Oban jobs.
  """

  use FreeObanUiWeb, :live_view

  import Ecto.Query

  alias FreeObanUi.Repo

  @states ~w(available scheduled executing retryable completed discarded cancelled)
  @default_state "available"

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(state: @default_state, states: @states, jobs: [])
      |> load_jobs()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    state = Map.get(params, "state", @default_state)
    state = if state in @states, do: state, else: @default_state

    {:noreply, socket |> assign(state: state) |> load_jobs()}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, load_jobs(socket)}
  end

  @impl true
  def handle_event("cancel_job", %{"id" => id}, socket) do
    id |> String.to_integer() |> Oban.cancel_job()
    {:noreply, load_jobs(socket)}
  end

  @impl true
  def handle_event("retry_job", %{"id" => id}, socket) do
    id |> String.to_integer() |> Oban.retry_job()
    {:noreply, load_jobs(socket)}
  end

  @impl true
  def handle_event("delete_job", %{"id" => id}, socket) do
    id
    |> String.to_integer()
    |> then(fn id -> from(j in Oban.Job, where: j.id == ^id) end)
    |> Repo.delete_all()

    {:noreply, load_jobs(socket)}
  end

  defp load_jobs(socket) do
    jobs =
      Oban.Job
      |> where([j], j.state == ^socket.assigns.state)
      |> order_by([j], desc: j.inserted_at)
      |> limit(50)
      |> Repo.all()

    assign(socket, jobs: jobs)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-lg font-semibold leading-8 text-zinc-800">Oban Jobs</h1>

      <div class="mt-4 flex flex-wrap gap-2">
        <.link
          :for={state <- @states}
          patch={~p"/oban?state=#{state}"}
          class={[
            "rounded-lg px-3 py-1 text-sm font-medium",
            state == @state && "bg-zinc-800 text-white",
            state != @state && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
          ]}
        >
          <%= state %>
        </.link>

        <button
          phx-click="refresh"
          class="ml-auto rounded-lg bg-zinc-100 px-3 py-1 text-sm font-medium text-zinc-700 hover:bg-zinc-200"
        >
          Refresh
        </button>
      </div>

      <table class="mt-6 w-full text-left text-sm">
        <thead>
          <tr class="border-b border-zinc-200 text-zinc-500">
            <th class="py-2 pr-4">ID</th>
            <th class="py-2 pr-4">Worker</th>
            <th class="py-2 pr-4">Queue</th>
            <th class="py-2 pr-4">Attempt</th>
            <th class="py-2 pr-4">Inserted at</th>
            <th class="py-2 pr-4">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={job <- @jobs} class="border-b border-zinc-100">
            <td class="py-2 pr-4"><%= job.id %></td>
            <td class="py-2 pr-4"><%= job.worker %></td>
            <td class="py-2 pr-4"><%= job.queue %></td>
            <td class="py-2 pr-4"><%= job.attempt %>/<%= job.max_attempts %></td>
            <td class="py-2 pr-4"><%= job.inserted_at %></td>
            <td class="py-2 pr-4">
              <div class="flex gap-2">
                <button
                  :if={@state in ~w(retryable discarded cancelled)}
                  phx-click="retry_job"
                  phx-value-id={job.id}
                  class="text-blue-600 hover:underline"
                >
                  Retry
                </button>
                <button
                  :if={@state in ~w(available scheduled executing retryable)}
                  phx-click="cancel_job"
                  phx-value-id={job.id}
                  class="text-amber-600 hover:underline"
                >
                  Cancel
                </button>
                <button
                  phx-click="delete_job"
                  phx-value-id={job.id}
                  data-confirm="Delete this job?"
                  class="text-red-600 hover:underline"
                >
                  Delete
                </button>
              </div>
            </td>
          </tr>
          <tr :if={@jobs == []}>
            <td colspan="6" class="py-4 text-center text-zinc-500">
              No jobs in the "<%= @state %>" state.
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end
end
