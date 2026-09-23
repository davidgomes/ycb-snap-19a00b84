defmodule FreeObanUiWeb.JobLive.Index do
  use FreeObanUiWeb, :live_view

  import FreeObanUiWeb.JobComponents

  alias FreeObanUi.Jobs

  @refresh_interval :timer.seconds(2)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(@refresh_interval, :refresh)

    {:ok, assign(socket, page_title: "Jobs", states: Jobs.states())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    state = if params["state"] in Jobs.states(), do: params["state"]

    {:noreply, socket |> assign(:state, state) |> load_jobs()}
  end

  @impl true
  def handle_info(:refresh, socket), do: {:noreply, load_jobs(socket)}

  @impl true
  def handle_event(action, %{"id" => id}, socket) when action in ~w(retry cancel delete) do
    socket =
      case Jobs.get_job(id) do
        nil -> put_flash(socket, :error, "Job #{id} no longer exists")
        job -> perform(socket, action, job)
      end

    {:noreply, load_jobs(socket)}
  end

  defp perform(socket, "retry", job) do
    :ok = Jobs.retry_job(job)
    put_flash(socket, :info, "Job #{job.id} queued for retry")
  end

  defp perform(socket, "cancel", job) do
    :ok = Jobs.cancel_job(job)
    put_flash(socket, :info, "Job #{job.id} cancelled")
  end

  defp perform(socket, "delete", job) do
    :ok = Jobs.delete_job(job)
    put_flash(socket, :info, "Job #{job.id} deleted")
  end

  defp load_jobs(socket) do
    assign(socket,
      jobs: Jobs.list_jobs(state: socket.assigns.state),
      counts: Jobs.count_by_state()
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Jobs
      <:subtitle>Oban jobs, newest first. Refreshes automatically.</:subtitle>
    </.header>

    <nav id="state-filters" class="mt-6 flex flex-wrap gap-2 text-sm">
      <.link patch={~p"/jobs"} class={["rounded-lg px-2 py-1", filter_class(@state == nil)]}>
        all (<%= @counts |> Map.values() |> Enum.sum() %>)
      </.link>
      <.link
        :for={state <- @states}
        id={"filter-#{state}"}
        patch={~p"/jobs?#{[state: state]}"}
        class={["rounded-lg px-2 py-1", filter_class(@state == state)]}
      >
        <%= state %> (<%= @counts[state] %>)
      </.link>
    </nav>

    <p :if={@jobs == []} id="no-jobs" class="mt-10 text-sm text-zinc-500">No jobs found.</p>

    <.table
      :if={@jobs != []}
      id="jobs"
      rows={@jobs}
      row_id={&"job-#{&1.id}"}
      row_click={&JS.navigate(~p"/jobs/#{&1.id}")}
    >
      <:col :let={job} label="ID"><%= job.id %></:col>
      <:col :let={job} label="Worker">
        <span title={job.worker}><%= short_worker(job.worker) %></span>
      </:col>
      <:col :let={job} label="Queue"><%= job.queue %></:col>
      <:col :let={job} label="State"><.state_badge state={job.state} /></:col>
      <:col :let={job} label="Attempt"><%= job.attempt %>/<%= job.max_attempts %></:col>
      <:action :let={job}>
        <.link :if={Jobs.retryable?(job)} phx-click="retry" phx-value-id={job.id}>Retry</.link>
      </:action>
      <:action :let={job}>
        <.link :if={Jobs.cancellable?(job)} phx-click="cancel" phx-value-id={job.id}>
          Cancel
        </.link>
      </:action>
      <:action :let={job}>
        <.link
          :if={Jobs.deletable?(job)}
          phx-click="delete"
          phx-value-id={job.id}
          data-confirm="Delete this job?"
        >
          Delete
        </.link>
      </:action>
    </.table>
    """
  end

  defp filter_class(true), do: "bg-zinc-900 text-white"
  defp filter_class(false), do: "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
end
