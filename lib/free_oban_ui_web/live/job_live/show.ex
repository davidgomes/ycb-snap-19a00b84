defmodule FreeObanUiWeb.JobLive.Show do
  use FreeObanUiWeb, :live_view

  alias FreeObanUi.Jobs

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Job")}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    job = Jobs.get_job!(id)
    {:noreply, assign(socket, job: job, page_title: "Job ##{job.id}")}
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    case Jobs.cancel_job(socket.assigns.job) do
      {:ok, job} ->
        {:noreply, socket |> assign(:job, job) |> put_flash(:info, "Job cancelled")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not cancel job: #{inspect(reason)}")}
    end
  end

  def handle_event("retry", _params, socket) do
    case Jobs.retry_job(socket.assigns.job) do
      {:ok, job} ->
        {:noreply, socket |> assign(:job, job) |> put_flash(:info, "Job queued for retry")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not retry job: #{inspect(reason)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Job #<%= @job.id %>
        <:subtitle><%= @job.worker %></:subtitle>
        <:actions>
          <.button :if={cancellable?(@job)} phx-click="cancel">Cancel</.button>
          <.button :if={retryable?(@job)} phx-click="retry">Retry</.button>
        </:actions>
      </.header>

      <.list>
        <:item title="State"><%= @job.state %></:item>
        <:item title="Queue"><%= @job.queue %></:item>
        <:item title="Attempt"><%= @job.attempt %>/<%= @job.max_attempts %></:item>
        <:item title="Priority"><%= @job.priority %></:item>
        <:item title="Args"><pre class="whitespace-pre-wrap text-sm"><%= inspect(@job.args, pretty: true) %></pre></:item>
        <:item title="Errors"><pre class="whitespace-pre-wrap text-sm"><%= inspect(@job.errors, pretty: true) %></pre></:item>
        <:item title="Inserted"><%= format_time(@job.inserted_at) %></:item>
        <:item title="Scheduled"><%= format_time(@job.scheduled_at) %></:item>
        <:item title="Attempted"><%= format_time(@job.attempted_at) %></:item>
        <:item title="Completed"><%= format_time(@job.completed_at) %></:item>
      </.list>

      <.back navigate={~p"/jobs"}>Back to jobs</.back>
    </div>
    """
  end

  defp cancellable?(%{state: state}), do: state in ~w(available scheduled retryable executing)
  defp retryable?(%{state: state}), do: state in ~w(completed discarded cancelled retryable)

  defp format_time(nil), do: "—"
  defp format_time(datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
end
