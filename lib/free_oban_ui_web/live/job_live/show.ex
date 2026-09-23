defmodule FreeObanUiWeb.JobLive.Show do
  use FreeObanUiWeb, :live_view

  import FreeObanUiWeb.JobLive.Components

  alias FreeObanUi.Jobs

  @refresh_interval :timer.seconds(2)

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Job <%= @job.id %>
      <.state_badge state={@job.state} />
      <:subtitle><%= @job.worker %></:subtitle>
      <:actions>
        <.button :if={Jobs.retryable?(@job)} id="retry-job" phx-click="retry">Retry</.button>
        <.button :if={Jobs.cancellable?(@job)} id="cancel-job" phx-click="cancel">Cancel</.button>
        <.button
          :if={Jobs.deletable?(@job)}
          id="delete-job"
          phx-click="delete"
          data-confirm="Delete this job?"
          class="bg-rose-600 hover:bg-rose-500"
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
      <:item :for={{label, field} <- timestamps()} title={label}>
        <%= absolute_time(Map.get(@job, field)) %>
        <span :if={Map.get(@job, field)} class="text-zinc-500">
          (<%= relative_time(Map.get(@job, field)) %>)
        </span>
      </:item>
    </.list>

    <section class="mt-10">
      <h2 class="text-sm font-semibold leading-6 text-zinc-800">Args</h2>
      <pre id="job-args" class="mt-2 overflow-x-auto rounded-lg bg-zinc-50 p-4 text-xs"><%= pretty_json(@job.args) %></pre>
    </section>

    <section :if={@job.meta != %{}} class="mt-6">
      <h2 class="text-sm font-semibold leading-6 text-zinc-800">Meta</h2>
      <pre class="mt-2 overflow-x-auto rounded-lg bg-zinc-50 p-4 text-xs"><%= pretty_json(@job.meta) %></pre>
    </section>

    <section :if={@job.errors != []} id="job-errors" class="mt-6">
      <h2 class="text-sm font-semibold leading-6 text-zinc-800">Errors</h2>
      <div :for={error <- Enum.reverse(@job.errors)} class="mt-2 rounded-lg bg-rose-50 p-4">
        <p class="text-xs font-semibold text-rose-800">
          Attempt <%= error["attempt"] %> at <%= error["at"] %>
        </p>
        <pre class="mt-2 overflow-x-auto text-xs text-rose-900"><%= error["error"] %></pre>
      </div>
    </section>

    <.back navigate={~p"/jobs"}>Back to jobs</.back>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket), do: :timer.send_interval(@refresh_interval, self(), :refresh)

    case Jobs.get_job(id) do
      nil ->
        {:ok, socket |> put_flash(:error, "Job not found") |> push_navigate(to: ~p"/jobs")}

      job ->
        {:ok, socket |> assign(:page_title, "Job #{job.id}") |> assign(:job, job)}
    end
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

  @impl true
  def handle_info(:refresh, socket), do: {:noreply, reload_job(socket)}

  defp reload_job(socket) do
    case Jobs.get_job(socket.assigns.job.id) do
      nil -> socket |> put_flash(:error, "Job no longer exists") |> push_navigate(to: ~p"/jobs")
      job -> assign(socket, :job, job)
    end
  end

  defp timestamps do
    [
      {"Inserted at", :inserted_at},
      {"Scheduled at", :scheduled_at},
      {"Attempted at", :attempted_at},
      {"Completed at", :completed_at},
      {"Cancelled at", :cancelled_at},
      {"Discarded at", :discarded_at}
    ]
  end

  defp pretty_json(data), do: Jason.encode!(data, pretty: true)
end
