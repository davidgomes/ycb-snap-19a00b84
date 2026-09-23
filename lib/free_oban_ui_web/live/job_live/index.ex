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
  def handle_info(:refresh, socket) do
    {:noreply, load_jobs(socket)}
  end

  defp load_jobs(socket) do
    assign(socket,
      jobs: Jobs.list_jobs(state: socket.assigns.state),
      counts: Jobs.count_by_state(),
      now: DateTime.utc_now()
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Jobs
      <:subtitle>
        Most recent <%= if @state, do: "#{@state} " %>jobs, refreshed automatically.
      </:subtitle>
    </.header>

    <nav class="mt-6 flex flex-wrap gap-2 text-sm" aria-label="Job states">
      <.state_tab patch={~p"/jobs"} active={is_nil(@state)} count={Enum.sum(Map.values(@counts))}>
        all
      </.state_tab>
      <.state_tab
        :for={state <- @states}
        patch={~p"/jobs?#{[state: state]}"}
        active={@state == state}
        count={@counts[state]}
      >
        <%= state %>
      </.state_tab>
    </nav>

    <.table
      :if={@jobs != []}
      id="jobs"
      rows={@jobs}
      row_id={&"jobs-#{&1.id}"}
      row_click={fn job -> JS.navigate(~p"/jobs/#{job}") end}
    >
      <:col :let={job} label="ID"><%= job.id %></:col>
      <:col :let={job} label="Worker">
        <div class="font-mono text-xs"><%= job.worker %></div>
        <div class="mt-1 max-w-xs truncate font-mono text-xs font-normal text-zinc-500">
          <%= Jason.encode!(job.args) %>
        </div>
      </:col>
      <:col :let={job} label="Queue"><%= job.queue %></:col>
      <:col :let={job} label="State"><.state_badge state={job.state} /></:col>
      <:col :let={job} label="Attempt"><%= job.attempt %>/<%= job.max_attempts %></:col>
      <:col :let={job} label="Time">
        <.relative_time at={job_time(job)} now={@now} />
      </:col>
    </.table>

    <p :if={@jobs == []} id="no-jobs" class="mt-11 text-sm text-zinc-500">
      No jobs found.
    </p>
    """
  end

  attr :patch, :string, required: true
  attr :active, :boolean, required: true
  attr :count, :integer, required: true
  slot :inner_block, required: true

  defp state_tab(assigns) do
    ~H"""
    <.link
      patch={@patch}
      class={[
        "rounded-full px-3 py-1 font-medium",
        if(@active,
          do: "bg-zinc-900 text-white",
          else: "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
        )
      ]}
    >
      <%= render_slot(@inner_block) %>
      <span class={["ml-1", if(@active, do: "text-zinc-300", else: "text-zinc-500")]}>
        <%= @count %>
      </span>
    </.link>
    """
  end

  defp job_time(%{state: "completed"} = job), do: job.completed_at
  defp job_time(%{state: "cancelled"} = job), do: job.cancelled_at
  defp job_time(%{state: "discarded"} = job), do: job.discarded_at
  defp job_time(%{state: "executing"} = job), do: job.attempted_at
  defp job_time(job), do: job.scheduled_at
end
