defmodule FreeObanUiWeb.JobLive.Show do
  use FreeObanUiWeb, :live_view

  import FreeObanUiWeb.JobComponents

  alias FreeObanUi.Jobs

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case Jobs.get_job(id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Job not found")
         |> push_navigate(to: ~p"/jobs")}

      job ->
        {:noreply, assign(socket, job: job, page_title: "Job #{job.id}")}
    end
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:ok, job} = Jobs.cancel_job(socket.assigns.job)
    {:noreply, socket |> put_flash(:info, "Job cancelled") |> assign(:job, job)}
  end

  def handle_event("retry", _params, socket) do
    {:ok, job} = Jobs.retry_job(socket.assigns.job)
    {:noreply, socket |> put_flash(:info, "Job retried") |> assign(:job, job)}
  end

  def handle_event("delete", _params, socket) do
    {:ok, _} = Jobs.delete_job(socket.assigns.job)

    {:noreply,
     socket
     |> put_flash(:info, "Job deleted")
     |> push_navigate(to: ~p"/jobs")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Job <%= @job.id %>
      <:subtitle><%= @job.worker %></:subtitle>
      <:actions>
        <.button
          :if={@job.state in ["available", "scheduled", "executing", "retryable"]}
          id="cancel-job"
          type="button"
          phx-click="cancel"
        >
          Cancel
        </.button>
        <.button
          :if={@job.state in ["retryable", "cancelled", "completed", "discarded"]}
          id="retry-job"
          type="button"
          phx-click="retry"
          class="ml-2"
        >
          Retry
        </.button>
        <.button
          id="delete-job"
          type="button"
          phx-click="delete"
          data-confirm="Delete this job?"
          class="ml-2 bg-rose-700 hover:bg-rose-600"
        >
          Delete
        </.button>
      </:actions>
    </.header>

    <.list>
      <:item title="State"><.state_badge state={@job.state} /></:item>
      <:item title="Queue"><%= @job.queue %></:item>
      <:item title="Worker"><%= @job.worker %></:item>
      <:item title="Attempts"><%= @job.attempt %> / <%= @job.max_attempts %></:item>
      <:item title="Priority"><%= @job.priority %></:item>
      <:item title="Tags"><%= format_tags(@job.tags) %></:item>
      <:item title="Inserted"><%= format_dt(@job.inserted_at) %></:item>
      <:item title="Scheduled"><%= format_dt(@job.scheduled_at) %></:item>
      <:item title="Attempted"><%= format_dt(@job.attempted_at) %></:item>
      <:item title="Completed"><%= format_dt(@job.completed_at) %></:item>
      <:item title="Cancelled"><%= format_dt(@job.cancelled_at) %></:item>
      <:item title="Discarded"><%= format_dt(@job.discarded_at) %></:item>
    </.list>

    <section class="mt-10">
      <h2 class="text-base font-semibold text-zinc-800">Args</h2>
      <pre id="job-args" class="mt-3 overflow-x-auto rounded-lg bg-zinc-50 p-4 text-xs text-zinc-800"><%= pretty_json(@job.args) %></pre>
    </section>

    <section class="mt-8">
      <h2 class="text-base font-semibold text-zinc-800">Meta</h2>
      <pre id="job-meta" class="mt-3 overflow-x-auto rounded-lg bg-zinc-50 p-4 text-xs text-zinc-800"><%= pretty_json(@job.meta) %></pre>
    </section>

    <section :if={@job.errors != []} class="mt-8">
      <h2 class="text-base font-semibold text-zinc-800">Errors</h2>
      <div id="job-errors" class="mt-3 space-y-3">
        <pre
          :for={error <- @job.errors}
          class="overflow-x-auto rounded-lg bg-rose-50 p-4 text-xs text-rose-900"
        ><%= error_text(error) %></pre>
      </div>
    </section>

    <.back navigate={~p"/jobs"}>Back to jobs</.back>
    """
  end

  defp format_tags([]), do: "—"
  defp format_tags(nil), do: "—"
  defp format_tags(tags), do: Enum.join(tags, ", ")

  defp error_text(error) when is_map(error) do
    error["error"] || pretty_json(error)
  end
end
