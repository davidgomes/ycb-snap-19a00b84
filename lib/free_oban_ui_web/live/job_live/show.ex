defmodule FreeObanUiWeb.JobLive.Show do
  use FreeObanUiWeb, :live_view

  alias FreeObanUi.Jobs

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Job #{id}")
     |> assign(:job, Jobs.get_job!(id))}
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    case Jobs.cancel_job(socket.assigns.job) do
      :ok ->
        job = Jobs.get_job!(socket.assigns.job.id)
        {:noreply, socket |> put_flash(:info, "Job cancelled") |> assign(:job, job)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not cancel job: #{inspect(reason)}")}
    end
  end

  def handle_event("retry", _params, socket) do
    case Jobs.retry_job(socket.assigns.job) do
      :ok ->
        job = Jobs.get_job!(socket.assigns.job.id)
        {:noreply, socket |> put_flash(:info, "Job queued for retry") |> assign(:job, job)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not retry job: #{inspect(reason)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between gap-4">
        <div>
          <.link navigate={~p"/jobs"} class="text-sm text-zinc-500 hover:text-zinc-800">&larr; All jobs</.link>
          <h1 class="mt-1 text-2xl font-semibold text-zinc-900">Job <%= @job.id %></h1>
          <p class="mt-1 font-mono text-sm text-zinc-600"><%= @job.worker %></p>
        </div>
        <div class="flex gap-2">
          <button
            :if={@job.state in ["completed", "cancelled", "discarded"]}
            phx-click="retry"
            class="rounded-lg bg-zinc-900 px-3 py-2 text-sm font-semibold text-white"
          >
            Retry
          </button>
          <button
            :if={@job.state in ["available", "scheduled", "retryable", "executing"]}
            phx-click="cancel"
            data-confirm="Cancel this job?"
            class="rounded-lg bg-rose-600 px-3 py-2 text-sm font-semibold text-white"
          >
            Cancel
          </button>
        </div>
      </div>

      <.list>
        <:item title="State"><%= @job.state %></:item>
        <:item title="Queue"><%= @job.queue %></:item>
        <:item title="Attempt"><%= @job.attempt %> / <%= @job.max_attempts %></:item>
        <:item title="Priority"><%= @job.priority %></:item>
        <:item title="Tags"><%= Enum.join(@job.tags || [], ", ") %></:item>
        <:item title="Inserted"><%= format_dt(@job.inserted_at) %></:item>
        <:item title="Scheduled"><%= format_dt(@job.scheduled_at) %></:item>
        <:item title="Attempted"><%= format_dt(@job.attempted_at) %></:item>
        <:item title="Completed"><%= format_dt(@job.completed_at) %></:item>
        <:item title="Cancelled"><%= format_dt(@job.cancelled_at) %></:item>
      </.list>

      <section>
        <h2 class="text-sm font-semibold text-zinc-900">Args</h2>
        <pre class="mt-2 overflow-x-auto rounded-lg bg-zinc-900 p-4 text-xs text-zinc-100"><%= pretty(@job.args) %></pre>
      </section>

      <section :if={@job.errors != []}>
        <h2 class="text-sm font-semibold text-zinc-900">Errors</h2>
        <pre class="mt-2 overflow-x-auto rounded-lg bg-rose-50 p-4 text-xs text-rose-900"><%= pretty(@job.errors) %></pre>
      </section>

      <section>
        <h2 class="text-sm font-semibold text-zinc-900">Meta</h2>
        <pre class="mt-2 overflow-x-auto rounded-lg bg-zinc-100 p-4 text-xs text-zinc-800"><%= pretty(@job.meta) %></pre>
      </section>
    </div>
    """
  end

  defp pretty(term), do: Jason.encode!(term, pretty: true)

  defp format_dt(nil), do: "—"
  defp format_dt(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  defp format_dt(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
end
