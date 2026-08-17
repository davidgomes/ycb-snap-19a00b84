defmodule FreeObanUiWeb.JobLive.Index do
  @moduledoc """
  A basic dashboard for browsing and managing Oban jobs.
  """
  use FreeObanUiWeb, :live_view

  import Ecto.Query

  alias FreeObanUi.Repo
  alias Oban.Job

  @states ~w(executing available scheduled retryable cancelled discarded completed)
  @refresh_interval :timer.seconds(2)
  @per_page 50

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(@refresh_interval, self(), :refresh)

    {:ok, assign(socket, states: @states)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    state = if params["state"] in @states, do: params["state"], else: "executing"
    queue = normalize_queue(params["queue"])

    {:noreply,
     socket
     |> assign(state: state, queue: queue)
     |> reload()}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, reload(socket)}
  end

  @impl true
  def handle_event("filter_queue", %{"queue" => queue}, socket) do
    {:noreply, push_patch(socket, to: state_path(socket.assigns.state, queue))}
  end

  def handle_event("cancel_job", %{"id" => id}, socket) do
    id |> String.to_integer() |> Oban.cancel_job()
    {:noreply, reload(socket)}
  end

  def handle_event("retry_job", %{"id" => id}, socket) do
    id |> String.to_integer() |> Oban.retry_job()
    {:noreply, reload(socket)}
  end

  def handle_event("delete_job", %{"id" => id}, socket) do
    Repo.delete_all(from j in Job, where: j.id == ^String.to_integer(id))
    {:noreply, reload(socket)}
  end

  defp reload(socket) do
    assign(socket,
      jobs: list_jobs(socket.assigns.state, socket.assigns.queue),
      counts: job_counts(),
      queues: list_queues()
    )
  end

  defp normalize_queue(nil), do: nil
  defp normalize_queue(""), do: nil
  defp normalize_queue(queue), do: queue

  defp list_jobs(state, queue) do
    Job
    |> where([j], j.state == ^state)
    |> filter_queue(queue)
    |> order_by(^order_for_state(state))
    |> limit(^@per_page)
    |> Repo.all()
  end

  defp filter_queue(query, nil), do: query
  defp filter_queue(query, queue), do: where(query, [j], j.queue == ^queue)

  defp order_for_state(state) when state in ~w(available scheduled), do: [asc: :scheduled_at]
  defp order_for_state("executing"), do: [desc: :attempted_at]
  defp order_for_state(_state), do: [desc: :id]

  defp list_queues do
    Job
    |> select([j], j.queue)
    |> distinct(true)
    |> order_by([j], asc: j.queue)
    |> Repo.all()
  end

  defp job_counts do
    Job
    |> group_by([j], j.state)
    |> select([j], {j.state, count(j.id)})
    |> Repo.all()
    |> Map.new()
  end

  defp state_path(state, queue), do: ~p"/oban?#{[state: state, queue: queue || ""]}"

  defp cancelable?(state), do: state in ~w(available scheduled executing retryable)
  defp retryable?(state), do: state in ~w(cancelled discarded retryable)

  defp format_time(nil), do: "-"
  defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")

  defp format_args(args) when is_map(args) do
    args |> Jason.encode!() |> String.slice(0, 120)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Oban Jobs
      <:subtitle>A basic view into your application's background jobs.</:subtitle>
    </.header>

    <div class="mt-8 flex flex-wrap items-center gap-2 border-b border-zinc-200 pb-4 text-sm">
      <.link
        :for={s <- @states}
        patch={state_path(s, @queue)}
        class={[
          "rounded-full px-3 py-1 font-medium",
          s == @state && "bg-zinc-900 text-white",
          s != @state && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
        ]}
      >
        <%= String.capitalize(s) %> (<%= Map.get(@counts, s, 0) %>)
      </.link>

      <form phx-change="filter_queue" class="ml-auto">
        <select name="queue" class="rounded-md border border-zinc-300 text-sm">
          <option value="">All queues</option>
          <option :for={q <- @queues} value={q} selected={q == @queue}><%= q %></option>
        </select>
      </form>
    </div>

    <.table id="jobs" rows={@jobs}>
      <:col :let={job} label="ID"><%= job.id %></:col>
      <:col :let={job} label="Worker"><%= job.worker %></:col>
      <:col :let={job} label="Queue"><%= job.queue %></:col>
      <:col :let={job} label="Attempt"><%= job.attempt %>/<%= job.max_attempts %></:col>
      <:col :let={job} label="Args"><%= format_args(job.args) %></:col>
      <:col :let={job} label="Inserted"><%= format_time(job.inserted_at) %></:col>
      <:col :let={job} label="Scheduled"><%= format_time(job.scheduled_at) %></:col>
      <:action :let={job}>
        <.link
          :if={cancelable?(job.state)}
          phx-click="cancel_job"
          phx-value-id={job.id}
          data-confirm="Cancel this job?"
        >
          Cancel
        </.link>
        <.link
          :if={retryable?(job.state)}
          phx-click="retry_job"
          phx-value-id={job.id}
          data-confirm="Retry this job?"
        >
          Retry
        </.link>
        <.link phx-click="delete_job" phx-value-id={job.id} data-confirm="Delete this job?">
          Delete
        </.link>
      </:action>
    </.table>

    <p :if={@jobs == []} class="mt-6 text-sm text-zinc-500">
      No <%= @state %> jobs<%= if @queue, do: " in the \"#{@queue}\" queue" %>.
    </p>
    """
  end
end
