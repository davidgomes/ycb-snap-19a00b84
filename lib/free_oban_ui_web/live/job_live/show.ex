defmodule FreeObanUiWeb.JobLive.Show do
  use FreeObanUiWeb, :live_view

  import FreeObanUiWeb.JobComponents

  alias FreeObanUi.Jobs

  @refresh_interval :timer.seconds(2)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    job = Jobs.get_job!(id)

    if connected?(socket), do: :timer.send_interval(@refresh_interval, :refresh)

    {:ok, assign(socket, page_title: "Job #{job.id}", job: job, now: DateTime.utc_now())}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, reload_job(socket)}
  end

  @impl true
  def handle_event("retry", _params, socket) do
    :ok = Jobs.retry_job(socket.assigns.job)

    {:noreply, socket |> put_flash(:info, "Job retried") |> reload_job()}
  end

  def handle_event("cancel", _params, socket) do
    :ok = Jobs.cancel_job(socket.assigns.job)

    {:noreply, socket |> put_flash(:info, "Job cancelled") |> reload_job()}
  end

  def handle_event("delete", _params, socket) do
    :ok = Jobs.delete_job(socket.assigns.job)

    {:noreply, socket |> put_flash(:info, "Job deleted") |> push_navigate(to: ~p"/jobs")}
  end

  defp reload_job(socket) do
    case Jobs.get_job(socket.assigns.job.id) do
      nil ->
        socket
        |> put_flash(:error, "Job #{socket.assigns.job.id} no longer exists")
        |> push_navigate(to: ~p"/jobs")

      job ->
        assign(socket, job: job, now: DateTime.utc_now())
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      <span class="font-mono"><%= @job.worker %></span>
      <.state_badge state={@job.state} />
      <:subtitle>Job <%= @job.id %> in the <%= @job.queue %> queue</:subtitle>
      <:actions>
        <.button :if={Jobs.retryable?(@job)} id="retry-job" phx-click="retry">Retry</.button>
        <.button :if={Jobs.cancellable?(@job)} id="cancel-job" phx-click="cancel">
          Cancel
        </.button>
        <.button
          :if={Jobs.deletable?(@job)}
          id="delete-job"
          phx-click="delete"
          data-confirm="Are you sure you want to delete this job?"
        >
          Delete
        </.button>
      </:actions>
    </.header>

    <.list>
      <:item title="Attempt"><%= @job.attempt %>/<%= @job.max_attempts %></:item>
      <:item title="Priority"><%= @job.priority %></:item>
      <:item title="Tags"><%= if @job.tags == [], do: "-", else: Enum.join(@job.tags, ", ") %></:item>
      <:item title="Attempted by"><%= Enum.join(@job.attempted_by || [], ", ") %></:item>
      <:item :for={{label, field} <- timestamps()} title={label}>
        <.relative_time at={Map.fetch!(@job, field)} now={@now} />
      </:item>
    </.list>

    <section class="mt-10">
      <h2 class="text-sm font-semibold leading-6 text-zinc-800">Args</h2>
      <pre id="job-args" class="mt-2 overflow-x-auto rounded-lg bg-zinc-50 p-4 text-xs"><%= pretty_json(@job.args) %></pre>
    </section>

    <section :if={@job.meta != %{}} class="mt-10">
      <h2 class="text-sm font-semibold leading-6 text-zinc-800">Meta</h2>
      <pre id="job-meta" class="mt-2 overflow-x-auto rounded-lg bg-zinc-50 p-4 text-xs"><%= pretty_json(@job.meta) %></pre>
    </section>

    <section :if={@job.errors != []} class="mt-10">
      <h2 class="text-sm font-semibold leading-6 text-zinc-800">Errors</h2>
      <div
        :for={error <- Enum.reverse(@job.errors)}
        class="mt-2 rounded-lg border border-rose-100 bg-rose-50 p-4 text-xs"
      >
        <p class="font-semibold text-rose-800">
          Attempt <%= error["attempt"] %> at <%= error["at"] %>
        </p>
        <pre class="mt-2 overflow-x-auto whitespace-pre-wrap text-rose-700"><%= error["error"] %></pre>
      </div>
    </section>

    <.back navigate={~p"/jobs"}>Back to jobs</.back>
    """
  end

  defp timestamps do
    [
      {"Inserted", :inserted_at},
      {"Scheduled", :scheduled_at},
      {"Attempted", :attempted_at},
      {"Completed", :completed_at},
      {"Cancelled", :cancelled_at},
      {"Discarded", :discarded_at}
    ]
  end
end
