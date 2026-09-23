defmodule FreeObanUiWeb.JobLive.Show do
  use FreeObanUiWeb, :live_view

  import FreeObanUiWeb.JobComponents

  alias FreeObanUi.Jobs

  @refresh_interval :timer.seconds(2)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(@refresh_interval, :refresh)

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    {:noreply, socket |> assign(id: id, page_title: "Job #{id}") |> load_job()}
  end

  @impl true
  def handle_info(:refresh, socket), do: {:noreply, load_job(socket)}

  @impl true
  def handle_event("retry", _params, socket) do
    :ok = Jobs.retry_job(socket.assigns.job)
    {:noreply, socket |> put_flash(:info, "Job queued for retry") |> load_job()}
  end

  def handle_event("cancel", _params, socket) do
    :ok = Jobs.cancel_job(socket.assigns.job)
    {:noreply, socket |> put_flash(:info, "Job cancelled") |> load_job()}
  end

  def handle_event("delete", _params, socket) do
    :ok = Jobs.delete_job(socket.assigns.job)
    {:noreply, socket |> put_flash(:info, "Job deleted") |> push_navigate(to: ~p"/jobs")}
  end

  defp load_job(socket) do
    case Integer.parse(socket.assigns.id) do
      {id, ""} -> Jobs.get_job(id)
      _ -> nil
    end
    |> case do
      nil ->
        socket
        |> put_flash(:error, "Job #{socket.assigns.id} not found")
        |> push_navigate(to: ~p"/jobs")

      job ->
        assign(socket, :job, job)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Job <%= @job.id %> <.state_badge state={@job.state} />
      <:subtitle><%= @job.worker %></:subtitle>
      <:actions>
        <.button :if={Jobs.retryable?(@job)} id="retry-job" phx-click="retry">Retry</.button>
        <.button :if={Jobs.cancellable?(@job)} id="cancel-job" phx-click="cancel">Cancel</.button>
        <.button
          :if={Jobs.deletable?(@job)}
          id="delete-job"
          phx-click="delete"
          data-confirm="Delete this job?"
        >
          Delete
        </.button>
      </:actions>
    </.header>

    <.list>
      <:item title="Queue"><%= @job.queue %></:item>
      <:item title="Attempt"><%= @job.attempt %>/<%= @job.max_attempts %></:item>
      <:item title="Priority"><%= @job.priority %></:item>
      <:item title="Tags"><%= Enum.join(@job.tags, ", ") %></:item>
      <:item title="Attempted by"><%= Enum.join(@job.attempted_by || [], ", ") %></:item>
      <:item title="Inserted at"><%= format_time(@job.inserted_at) %></:item>
      <:item title="Scheduled at"><%= format_time(@job.scheduled_at) %></:item>
      <:item title="Attempted at"><%= format_time(@job.attempted_at) %></:item>
      <:item title="Completed at"><%= format_time(@job.completed_at) %></:item>
      <:item title="Cancelled at"><%= format_time(@job.cancelled_at) %></:item>
      <:item title="Discarded at"><%= format_time(@job.discarded_at) %></:item>
    </.list>

    <h2 class="mt-10 text-sm font-semibold text-zinc-800">Args</h2>
    <pre id="job-args" class="mt-2 overflow-x-auto rounded-lg bg-zinc-50 p-4 text-xs"><%= pretty_json(@job.args) %></pre>

    <h2 class="mt-10 text-sm font-semibold text-zinc-800">Meta</h2>
    <pre id="job-meta" class="mt-2 overflow-x-auto rounded-lg bg-zinc-50 p-4 text-xs"><%= pretty_json(@job.meta) %></pre>

    <h2 class="mt-10 text-sm font-semibold text-zinc-800">Errors</h2>
    <p :if={@job.errors == []} class="mt-2 text-sm text-zinc-500">No errors.</p>
    <div :for={error <- Enum.reverse(@job.errors)} class="mt-2 rounded-lg bg-rose-50 p-4 text-xs">
      <p class="font-semibold text-rose-800">
        Attempt <%= error["attempt"] %> at <%= error["at"] %>
      </p>
      <pre class="mt-2 overflow-x-auto whitespace-pre-wrap text-rose-900"><%= error["error"] %></pre>
    </div>

    <.back navigate={~p"/jobs"}>Back to jobs</.back>
    """
  end

  defp pretty_json(term), do: Jason.encode!(term, pretty: true)
end
