defmodule FreeObanUiWeb.JobsLive do
  use FreeObanUiWeb, :live_view

  alias FreeObanUi.Jobs

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, states: Jobs.states())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    state = if params["state"] in Jobs.states(), do: params["state"]

    {:noreply,
     assign(socket,
       state: state,
       counts: Jobs.count_by_state(),
       jobs: Jobs.list_jobs(state: state)
     )}
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
        :for={s <- @states}
        patch={~p"/jobs?state=#{s}"}
        class={["rounded px-3 py-1", @state == s && "bg-zinc-900 text-white"]}
      >
        <%= s %> (<%= @counts[s] %>)
      </.link>
    </nav>

    <.table id="jobs" rows={@jobs}>
      <:col :let={job} label="ID"><%= job.id %></:col>
      <:col :let={job} label="Worker"><%= job.worker %></:col>
      <:col :let={job} label="Queue"><%= job.queue %></:col>
      <:col :let={job} label="State"><%= job.state %></:col>
      <:col :let={job} label="Attempt"><%= job.attempt %>/<%= job.max_attempts %></:col>
      <:col :let={job} label="Args"><code><%= Jason.encode!(job.args) %></code></:col>
      <:col :let={job} label="Inserted"><%= job.inserted_at %></:col>
    </.table>
    """
  end
end
