defmodule FreeObanUiWeb.JobLive.Show do
  use FreeObanUiWeb, :live_view

  import FreeObanUiWeb.JobComponents

  alias FreeObanUi.Jobs

  @refresh_interval :timer.seconds(2)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Integer.parse(id) do
      {job_id, ""} ->
        if connected?(socket), do: schedule_refresh()

        {:ok, socket |> assign(:job_id, job_id) |> load_job()}

      _ ->
        {:ok, job_not_found(socket)}
    end
  end

  @impl true
  def handle_info(:refresh, socket) do
    schedule_refresh()

    {:noreply, load_job(socket)}
  end

  @impl true
  def handle_event("retry", _params, socket) do
    :ok = Jobs.retry_job(socket.assigns.job)

    {:noreply, socket |> put_flash(:info, "Job retried") |> load_job()}
  end

  def handle_event("cancel", _params, socket) do
    :ok = Jobs.cancel_job(socket.assigns.job)

    {:noreply, socket |> put_flash(:info, "Job cancelled") |> load_job()}
  end

  def handle_event("delete", _params, socket) do
    {:ok, _job} = Jobs.delete_job(socket.assigns.job)

    {:noreply, socket |> put_flash(:info, "Job deleted") |> push_navigate(to: ~p"/jobs")}
  end

  defp schedule_refresh, do: Process.send_after(self(), :refresh, @refresh_interval)

  defp load_job(socket) do
    case Jobs.get_job(socket.assigns.job_id) do
      nil -> job_not_found(socket)
      job -> assign(socket, job: job, page_title: "Job #{job.id}")
    end
  end

  defp job_not_found(socket) do
    socket
    |> put_flash(:error, "Job not found")
    |> push_navigate(to: ~p"/jobs")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Job <%= @job.id %>
      <:subtitle><%= @job.worker %></:subtitle>
      <:actions>
        <div class="flex gap-2">
          <.button :if={Jobs.retryable?(@job)} id="retry-job" phx-click="retry">
            Retry
          </.button>
          <.button
            :if={Jobs.cancellable?(@job)}
            id="cancel-job"
            phx-click="cancel"
            data-confirm="Cancel this job?"
          >
            Cancel
          </.button>
          <.button
            :if={Jobs.deletable?(@job)}
            id="delete-job"
            phx-click="delete"
            data-confirm="Permanently delete this job?"
          >
            Delete
          </.button>
        </div>
      </:actions>
    </.header>

    <.list>
      <:item title="State"><.state_badge state={@job.state} /></:item>
      <:item title="Queue"><%= @job.queue %></:item>
      <:item title="Attempt"><%= @job.attempt %> of <%= @job.max_attempts %></:item>
      <:item title="Priority"><%= @job.priority %></:item>
      <:item title="Tags"><%= Enum.join(@job.tags, ", ") %></:item>
      <:item title="Attempted by"><%= Enum.join(@job.attempted_by || [], ", ") %></:item>
      <:item title="Inserted at"><%= format_timestamp(@job.inserted_at) %></:item>
      <:item title="Scheduled at"><%= format_timestamp(@job.scheduled_at) %></:item>
      <:item title="Attempted at"><%= format_timestamp(@job.attempted_at) %></:item>
      <:item title="Completed at"><%= format_timestamp(@job.completed_at) %></:item>
      <:item title="Discarded at"><%= format_timestamp(@job.discarded_at) %></:item>
      <:item title="Cancelled at"><%= format_timestamp(@job.cancelled_at) %></:item>
    </.list>

    <section id="job-args" class="mt-12">
      <h2 class="text-sm font-semibold leading-6 text-zinc-800">Args</h2>
      <pre class="mt-2 overflow-x-auto rounded-lg bg-zinc-50 p-4 text-xs text-zinc-700"><%= format_json(@job.args, pretty: true) %></pre>
    </section>

    <section id="job-meta" class="mt-8">
      <h2 class="text-sm font-semibold leading-6 text-zinc-800">Meta</h2>
      <pre class="mt-2 overflow-x-auto rounded-lg bg-zinc-50 p-4 text-xs text-zinc-700"><%= format_json(@job.meta, pretty: true) %></pre>
    </section>

    <section id="job-errors" class="mt-8">
      <h2 class="text-sm font-semibold leading-6 text-zinc-800">Errors</h2>
      <p :if={@job.errors == []} class="mt-2 text-sm text-zinc-500">No errors recorded.</p>
      <div :for={error <- Enum.reverse(@job.errors)} class="mt-2">
        <p class="text-xs text-zinc-500">
          Attempt <%= error["attempt"] %> at <%= error["at"] %>
        </p>
        <pre class="mt-1 overflow-x-auto rounded-lg bg-rose-50 p-4 text-xs text-rose-800"><%= error["error"] %></pre>
      </div>
    </section>

    <.back navigate={~p"/jobs"}>Back to jobs</.back>
    """
  end
end
