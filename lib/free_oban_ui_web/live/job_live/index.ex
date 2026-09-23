defmodule FreeObanUiWeb.JobLive.Index do
  use FreeObanUiWeb, :live_view

  alias FreeObanUi.Jobs

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Jobs")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = Map.take(params, ["state", "queue", "worker"])

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:counts, Jobs.counts_by_state())
     |> assign(:jobs, Jobs.list_jobs(filters))}
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters =
      params
      |> Map.take(["state", "queue", "worker"])
      |> Enum.reject(fn {_k, v} -> v in [nil, ""] end)
      |> Map.new()

    {:noreply, push_patch(socket, to: ~p"/jobs?#{filters}")}
  end

  def handle_event("cancel", %{"id" => id}, socket) do
    job = Jobs.get_job!(id)

    case Jobs.cancel_job(job) do
      :ok ->
        {:noreply, refresh(socket, "Job #{id} cancelled")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not cancel job: #{inspect(reason)}")}
    end
  end

  def handle_event("retry", %{"id" => id}, socket) do
    job = Jobs.get_job!(id)

    case Jobs.retry_job(job) do
      :ok ->
        {:noreply, refresh(socket, "Job #{id} queued for retry")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not retry job: #{inspect(reason)}")}
    end
  end

  defp refresh(socket, message) do
    filters = socket.assigns.filters

    socket
    |> put_flash(:info, message)
    |> assign(:counts, Jobs.counts_by_state())
    |> assign(:jobs, Jobs.list_jobs(filters))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-end justify-between gap-4">
        <div>
          <h1 class="text-2xl font-semibold text-zinc-900">Oban jobs</h1>
          <p class="mt-1 text-sm text-zinc-600">Latest 100 jobs. Filter by state, queue, or worker.</p>
        </div>
      </div>

      <div class="flex flex-wrap gap-2">
        <.state_pill label="all" count={Enum.sum(Map.values(@counts))} active={@filters["state"] in [nil, ""]} patch={~p"/jobs"} />
        <.state_pill
          :for={state <- Jobs.states()}
          label={state}
          count={Map.get(@counts, state, 0)}
          active={@filters["state"] == state}
          patch={~p"/jobs?#{Map.put(@filters, "state", state)}"}
        />
      </div>

      <form id="job-filters" phx-change="filter" class="grid gap-3 sm:grid-cols-3">
        <div>
          <label for="job-state" class="block text-sm font-medium text-zinc-700">State</label>
          <select id="job-state" name="state" class="mt-1 w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm">
            <option value="">Any</option>
            <option :for={state <- Jobs.states()} value={state} selected={@filters["state"] == state}>
              <%= state %>
            </option>
          </select>
        </div>
        <div>
          <label for="job-queue" class="block text-sm font-medium text-zinc-700">Queue</label>
          <input
            id="job-queue"
            type="text"
            name="queue"
            value={@filters["queue"]}
            placeholder="default"
            class="mt-1 w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm"
          />
        </div>
        <div>
          <label for="job-worker" class="block text-sm font-medium text-zinc-700">Worker</label>
          <input
            id="job-worker"
            type="text"
            name="worker"
            value={@filters["worker"]}
            placeholder="MyApp.Worker"
            class="mt-1 w-full rounded-lg border border-zinc-300 px-3 py-2 text-sm"
          />
        </div>
      </form>

      <.table id="jobs" rows={@jobs}>
        <:col :let={job} label="ID">
          <.link navigate={~p"/jobs/#{job.id}"} class="text-brand hover:underline"><%= job.id %></.link>
        </:col>
        <:col :let={job} label="State"><%= job.state %></:col>
        <:col :let={job} label="Queue"><%= job.queue %></:col>
        <:col :let={job} label="Worker"><span class="font-mono text-xs"><%= job.worker %></span></:col>
        <:col :let={job} label="Attempt"><%= job.attempt %>/<%= job.max_attempts %></:col>
        <:col :let={job} label="Scheduled"><%= format_dt(job.scheduled_at) %></:col>
        <:action :let={job}>
          <button
            :if={job.state in ["completed", "cancelled", "discarded"]}
            phx-click="retry"
            phx-value-id={job.id}
            class="text-brand hover:underline"
          >
            Retry
          </button>
          <button
            :if={job.state in ["available", "scheduled", "retryable", "executing"]}
            phx-click="cancel"
            phx-value-id={job.id}
            data-confirm="Cancel this job?"
            class="text-rose-600 hover:underline"
          >
            Cancel
          </button>
        </:action>
      </.table>

      <p :if={@jobs == []} class="text-sm text-zinc-500">No jobs match these filters.</p>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :count, :integer, required: true
  attr :active, :boolean, required: true
  attr :patch, :string, required: true

  defp state_pill(assigns) do
    ~H"""
    <.link
      patch={@patch}
      class={[
        "rounded-full px-3 py-1 text-sm",
        @active && "bg-zinc-900 text-white",
        !@active && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
      ]}
    >
      <%= @label %> <span class="opacity-70"><%= @count %></span>
    </.link>
    """
  end

  defp format_dt(nil), do: "—"
  defp format_dt(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
  defp format_dt(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
end
