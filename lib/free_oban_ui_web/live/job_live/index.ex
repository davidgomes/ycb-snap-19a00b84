defmodule FreeObanUiWeb.JobLive.Index do
  use FreeObanUiWeb, :live_view

  alias FreeObanUi.Jobs

  @refresh_interval 2_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(@refresh_interval, :refresh)

    {:ok, assign(socket, page_title: "Oban Jobs", states: Jobs.states())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    state = if params["state"] in Jobs.states(), do: params["state"]

    {:noreply, socket |> assign(state: state) |> load_jobs()}
  end

  @impl true
  def handle_event("cancel", %{"id" => id}, socket) do
    Oban.cancel_job(String.to_integer(id))
    {:noreply, load_jobs(socket)}
  end

  def handle_event("retry", %{"id" => id}, socket) do
    Oban.retry_job(String.to_integer(id))
    {:noreply, load_jobs(socket)}
  end

  @impl true
  def handle_info(:refresh, socket), do: {:noreply, load_jobs(socket)}

  defp load_jobs(socket) do
    assign(socket,
      jobs: Jobs.list_jobs(state: socket.assigns.state),
      counts: Jobs.count_by_state()
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>Oban Jobs</.header>

    <nav class="mt-6 flex flex-wrap gap-2 text-sm">
      <.link
        patch={~p"/jobs"}
        class={["rounded px-3 py-1", is_nil(@state) && "bg-zinc-900 text-white"]}
      >
        all
      </.link>
      <.link
        :for={state <- @states}
        patch={~p"/jobs?#{[state: state]}"}
        class={["rounded px-3 py-1", @state == state && "bg-zinc-900 text-white"]}
      >
        <%= state %> (<%= @counts[state] %>)
      </.link>
    </nav>

    <.table id="jobs" rows={@jobs}>
      <:col :let={job} label="ID"><%= job.id %></:col>
      <:col :let={job} label="Worker"><%= job.worker %></:col>
      <:col :let={job} label="Queue"><%= job.queue %></:col>
      <:col :let={job} label="State"><%= job.state %></:col>
      <:col :let={job} label="Attempt"><%= job.attempt %>/<%= job.max_attempts %></:col>
      <:col :let={job} label="Args"><code class="text-xs"><%= Jason.encode!(job.args) %></code></:col>
      <:col :let={job} label="Inserted"><%= job.inserted_at %></:col>
      <:action :let={job}>
        <.link
          :if={job.state in ~w(available scheduled retryable executing)}
          phx-click="cancel"
          phx-value-id={job.id}
        >
          Cancel
        </.link>
        <.link
          :if={job.state in ~w(retryable discarded cancelled completed)}
          phx-click="retry"
          phx-value-id={job.id}
        >
          Retry
        </.link>
      </:action>
    </.table>
    """
  end
end
