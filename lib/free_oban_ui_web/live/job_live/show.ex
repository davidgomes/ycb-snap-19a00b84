defmodule FreeObanUiWeb.JobLive.Show do
  use FreeObanUiWeb, :live_view

  import FreeObanUiWeb.JobLive.Components

  alias FreeObanUi.Jobs

  @retryable_states ~w(scheduled retryable completed discarded cancelled)
  @cancellable_states ~w(available scheduled executing retryable)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Integer.parse(id) do
      {id, ""} -> {:ok, assign(socket, id: id) |> load_job()}
      _ -> {:ok, not_found(socket)}
    end
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
    :ok = Jobs.delete_job(socket.assigns.job)

    {:noreply,
     socket
     |> put_flash(:info, "Job deleted")
     |> push_navigate(to: ~p"/jobs")}
  end

  @impl true
  def render(%{job: nil} = assigns), do: ~H""

  def render(assigns) do
    ~H"""
    <.header>
      Job <%= @job.id %>
      <:subtitle><%= @job.worker %></:subtitle>
      <:actions>
        <.button :if={@job.state in retryable_states()} id="retry-job" phx-click="retry">
          Retry
        </.button>
        <.button
          :if={@job.state in cancellable_states()}
          id="cancel-job"
          phx-click="cancel"
          data-confirm="Cancel this job?"
        >
          Cancel
        </.button>
        <.button
          :if={@job.state != "executing"}
          id="delete-job"
          phx-click="delete"
          data-confirm="Permanently delete this job?"
        >
          Delete
        </.button>
      </:actions>
    </.header>

    <.list>
      <:item title="State"><.state_badge state={@job.state} /></:item>
      <:item title="Queue"><%= @job.queue %></:item>
      <:item title="Attempt"><%= @job.attempt %>/<%= @job.max_attempts %></:item>
      <:item title="Priority"><%= @job.priority %></:item>
      <:item title="Tags"><%= Enum.join(@job.tags, ", ") %></:item>
      <:item title="Inserted at"><.timestamp at={@job.inserted_at} /></:item>
      <:item title="Scheduled at"><.timestamp at={@job.scheduled_at} /></:item>
      <:item title="Attempted at"><.timestamp at={@job.attempted_at} /></:item>
      <:item title="Completed at"><.timestamp at={@job.completed_at} /></:item>
      <:item title="Cancelled at"><.timestamp at={@job.cancelled_at} /></:item>
      <:item title="Discarded at"><.timestamp at={@job.discarded_at} /></:item>
    </.list>

    <section class="mt-10">
      <h2 class="text-sm font-semibold text-zinc-900">Args</h2>
      <pre id="job-args" class="mt-2 overflow-x-auto rounded-lg bg-zinc-50 p-4 text-xs"><%= pretty_json(@job.args) %></pre>
    </section>

    <section :if={@job.meta != %{}} class="mt-6">
      <h2 class="text-sm font-semibold text-zinc-900">Meta</h2>
      <pre id="job-meta" class="mt-2 overflow-x-auto rounded-lg bg-zinc-50 p-4 text-xs"><%= pretty_json(@job.meta) %></pre>
    </section>

    <section :if={@job.errors != []} class="mt-6" id="job-errors">
      <h2 class="text-sm font-semibold text-zinc-900">Errors</h2>
      <div :for={error <- Enum.reverse(@job.errors)} class="mt-2 rounded-lg bg-rose-50 p-4 text-xs">
        <p class="font-semibold text-rose-800">
          Attempt <%= error["attempt"] %> at <%= error["at"] %>
        </p>
        <pre class="mt-2 overflow-x-auto whitespace-pre-wrap text-rose-900"><%= error["error"] %></pre>
      </div>
    </section>

    <.back navigate={~p"/jobs"}>Back to jobs</.back>
    """
  end

  defp load_job(socket) do
    case Jobs.get_job(socket.assigns.id) do
      nil -> not_found(socket)
      job -> assign(socket, job: job, page_title: "Job #{job.id}")
    end
  end

  defp not_found(socket) do
    socket
    |> put_flash(:error, "Job not found")
    |> push_navigate(to: ~p"/jobs")
    |> assign(job: nil)
  end

  defp retryable_states, do: @retryable_states
  defp cancellable_states, do: @cancellable_states

  defp pretty_json(term), do: Jason.encode!(term, pretty: true)
end
