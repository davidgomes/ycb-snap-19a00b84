defmodule FreeObanUiWeb.JobLive.Index do
  use FreeObanUiWeb, :live_view

  import FreeObanUiWeb.JobComponents

  alias FreeObanUi.Jobs

  @refresh_interval :timer.seconds(2)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: schedule_refresh()

    {:ok, assign(socket, :page_title, "Jobs")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    state = if params["state"] in Jobs.states(), do: params["state"]

    {:noreply, socket |> assign(:state, state) |> load_jobs()}
  end

  @impl true
  def handle_info(:refresh, socket) do
    schedule_refresh()

    {:noreply, load_jobs(socket)}
  end

  defp schedule_refresh, do: Process.send_after(self(), :refresh, @refresh_interval)

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
      <:subtitle>The most recent Oban jobs, refreshed automatically.</:subtitle>
    </.header>

    <nav id="job-states" class="mt-8 flex flex-wrap gap-2 text-sm">
      <.state_tab current={@state} count={@counts |> Map.values() |> Enum.sum()} />
      <.state_tab
        :for={state <- Jobs.states()}
        state={state}
        current={@state}
        count={@counts[state]}
      />
    </nav>

    <p :if={@jobs == []} id="no-jobs" class="mt-11 text-sm text-zinc-500">
      No jobs found.
    </p>

    <.table
      :if={@jobs != []}
      id="jobs"
      rows={@jobs}
      row_id={&"job-#{&1.id}"}
      row_click={&JS.navigate(~p"/jobs/#{&1.id}")}
    >
      <:col :let={job} label="ID"><%= job.id %></:col>
      <:col :let={job} label="Worker"><%= job.worker %></:col>
      <:col :let={job} label="Queue"><%= job.queue %></:col>
      <:col :let={job} label="State"><.state_badge state={job.state} /></:col>
      <:col :let={job} label="Attempt"><%= job.attempt %>/<%= job.max_attempts %></:col>
      <:col :let={job} label="Args">
        <code class="block max-w-xs truncate font-mono text-xs"><%= format_json(job.args) %></code>
      </:col>
      <:col :let={job} label="Time"><.job_timestamp job={job} /></:col>
    </.table>
    """
  end

  attr :state, :string, default: nil
  attr :current, :string, default: nil
  attr :count, :integer, required: true

  defp state_tab(assigns) do
    ~H"""
    <.link
      id={"state-#{@state || "all"}"}
      patch={if @state, do: ~p"/jobs?#{[state: @state]}", else: ~p"/jobs"}
      class={[
        "rounded-full px-3 py-1 font-medium",
        if(@state == @current,
          do: "bg-zinc-900 text-white",
          else: "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
        )
      ]}
    >
      <%= @state || "all" %>
      <span class="ml-1 opacity-70"><%= @count %></span>
    </.link>
    """
  end
end
