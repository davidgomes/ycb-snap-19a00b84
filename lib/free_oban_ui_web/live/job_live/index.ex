defmodule FreeObanUiWeb.JobLive.Index do
  use FreeObanUiWeb, :live_view

  import FreeObanUiWeb.JobComponents

  alias FreeObanUi.Jobs

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Jobs")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, listing: Jobs.list_jobs(params), params: params)}
  end

  @impl true
  def handle_event("filter", params, socket) do
    query =
      params
      |> Map.take(["state", "queue", "worker"])
      |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
      |> Map.new()

    {:noreply, push_patch(socket, to: ~p"/jobs?#{query}")}
  end

  def handle_event("enqueue", %{"message" => message}, socket) do
    case Jobs.enqueue_ping(message) do
      {:ok, job} ->
        {:noreply,
         socket
         |> put_flash(:info, "Enqueued job #{job.id}")
         |> reload()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not enqueue job")}
    end
  end

  def handle_event("cancel", %{"id" => id}, socket) do
    {:noreply, run_action(socket, id, &Jobs.cancel_job/1, "Job cancelled")}
  end

  def handle_event("retry", %{"id" => id}, socket) do
    {:noreply, run_action(socket, id, &Jobs.retry_job/1, "Job retried")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Oban jobs
      <:subtitle>
        <%= @listing.total %> job<%= if @listing.total != 1, do: "s" %>
      </:subtitle>
      <:actions>
        <form id="enqueue-form" phx-submit="enqueue" class="flex items-center gap-2">
          <input
            type="text"
            name="message"
            placeholder="Sample message"
            class="rounded-lg border border-zinc-300 px-3 py-2 text-sm"
          />
          <.button>Enqueue sample</.button>
        </form>
      </:actions>
    </.header>

    <form id="job-filters" phx-change="filter" class="mt-8 grid gap-4 sm:grid-cols-3">
      <div>
        <label for="job-state" class="block text-sm font-semibold leading-6 text-zinc-800">
          State
        </label>
        <select
          id="job-state"
          name="state"
          class="mt-2 block w-full rounded-md border border-gray-300 bg-white shadow-sm focus:border-zinc-400 focus:ring-0 sm:text-sm"
        >
          <option value="" selected={@listing.filters.state in [nil, ""]}>
            All (<%= Enum.sum(Map.values(@listing.counts)) %>)
          </option>
          <option
            :for={state <- Jobs.states()}
            value={state}
            selected={@listing.filters.state == state}
          >
            <%= state %> (<%= Map.get(@listing.counts, state, 0) %>)
          </option>
        </select>
      </div>
      <div>
        <label for="job-queue" class="block text-sm font-semibold leading-6 text-zinc-800">
          Queue
        </label>
        <input
          id="job-queue"
          type="text"
          name="queue"
          value={@listing.filters.queue}
          placeholder="default"
          phx-debounce="300"
          class="mt-2 block w-full rounded-lg border border-zinc-300 text-zinc-900 focus:border-zinc-400 focus:ring-0 sm:text-sm sm:leading-6"
        />
      </div>
      <div>
        <label for="job-worker" class="block text-sm font-semibold leading-6 text-zinc-800">
          Worker
        </label>
        <input
          id="job-worker"
          type="text"
          name="worker"
          value={@listing.filters.worker}
          placeholder="PingWorker"
          phx-debounce="300"
          class="mt-2 block w-full rounded-lg border border-zinc-300 text-zinc-900 focus:border-zinc-400 focus:ring-0 sm:text-sm sm:leading-6"
        />
      </div>
    </form>

    <p :if={@listing.jobs == []} id="jobs-empty" class="mt-10 text-sm text-zinc-500">
      No jobs match these filters.
    </p>

    <.table id="jobs" rows={@listing.jobs} row_id={fn job -> "jobs-#{job.id}" end}>
      <:col :let={job} label="ID">
        <.link navigate={~p"/jobs/#{job.id}"} class="hover:underline">
          <%= job.id %>
        </.link>
      </:col>
      <:col :let={job} label="State"><.state_badge state={job.state} /></:col>
      <:col :let={job} label="Queue"><%= job.queue %></:col>
      <:col :let={job} label="Worker"><%= job.worker %></:col>
      <:col :let={job} label="Attempts"><%= job.attempt %>/<%= job.max_attempts %></:col>
      <:col :let={job} label="Scheduled"><%= format_dt(job.scheduled_at) %></:col>
      <:action :let={job}>
        <.link navigate={~p"/jobs/#{job.id}"} class="hover:underline">View</.link>
        <button
          :if={job.state in ["available", "scheduled", "executing", "retryable"]}
          id={"cancel-#{job.id}"}
          type="button"
          phx-click="cancel"
          phx-value-id={job.id}
          class="ml-3 hover:underline"
        >
          Cancel
        </button>
        <button
          :if={job.state in ["retryable", "cancelled", "completed", "discarded"]}
          id={"retry-#{job.id}"}
          type="button"
          phx-click="retry"
          phx-value-id={job.id}
          class="ml-3 hover:underline"
        >
          Retry
        </button>
      </:action>
    </.table>

    <div
      :if={@listing.total_pages > 1}
      id="jobs-pagination"
      class="mt-8 flex items-center gap-4 text-sm"
    >
      <.link
        :if={@listing.page > 1}
        patch={~p"/jobs?#{page_params(@params, @listing.page - 1)}"}
        class="font-semibold text-zinc-900 hover:text-zinc-700"
      >
        Previous
      </.link>
      <span class="text-zinc-500">
        Page <%= @listing.page %> of <%= @listing.total_pages %>
      </span>
      <.link
        :if={@listing.page < @listing.total_pages}
        patch={~p"/jobs?#{page_params(@params, @listing.page + 1)}"}
        class="font-semibold text-zinc-900 hover:text-zinc-700"
      >
        Next
      </.link>
    </div>
    """
  end

  defp run_action(socket, id, fun, message) do
    case Jobs.get_job(id) do
      nil ->
        put_flash(socket, :error, "Job not found")

      job ->
        {:ok, _} = fun.(job)

        socket
        |> put_flash(:info, message)
        |> reload()
    end
  end

  defp reload(socket) do
    assign(socket, :listing, Jobs.list_jobs(socket.assigns.params))
  end

  defp page_params(params, page) do
    params
    |> Map.take(["state", "queue", "worker"])
    |> Map.put("page", page)
    |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
    |> Map.new()
  end
end
