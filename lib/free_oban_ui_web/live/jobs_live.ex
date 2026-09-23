defmodule FreeObanUiWeb.JobsLive do
  use FreeObanUiWeb, :live_view

  import Ecto.Query

  alias FreeObanUi.Repo

  @states ~w(available scheduled executing retryable completed discarded cancelled)
  @limit 50

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(2_000, :refresh)

    {:ok, assign(socket, states: @states)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    state = if params["state"] in @states, do: params["state"], else: nil

    {:noreply, socket |> assign(state: state) |> load_jobs()}
  end

  @impl true
  def handle_info(:refresh, socket), do: {:noreply, load_jobs(socket)}

  defp load_jobs(socket) do
    query = from(j in Oban.Job, order_by: [desc: j.id], limit: @limit)
    query = if s = socket.assigns.state, do: where(query, [j], j.state == ^s), else: query

    counts =
      Oban.Job
      |> group_by([j], j.state)
      |> select([j], {j.state, count(j.id)})
      |> Repo.all()
      |> Map.new()

    assign(socket, jobs: Repo.all(query), counts: counts)
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
        all (<%= @counts |> Map.values() |> Enum.sum() %>)
      </.link>
      <.link
        :for={s <- @states}
        patch={~p"/jobs?#{[state: s]}"}
        class={["rounded px-3 py-1", @state == s && "bg-zinc-900 text-white"]}
      >
        <%= s %> (<%= Map.get(@counts, s, 0) %>)
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
    </.table>
    """
  end
end
