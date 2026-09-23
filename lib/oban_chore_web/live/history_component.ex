defmodule ObanChoreWeb.HistoryComponent do
  @moduledoc false
  use Phoenix.LiveComponent
  import ObanChoreWeb.CoreComponents

  @page_size 20

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns, :selected_job, Enum.find(assigns.jobs, &(&1.id == assigns.selected_job_id)))

    ~H"""
    <div class={if @selected, do: "oc-block", else: "oc-hidden"} data-role="history">
      <%= if @selected_job do %>
        <div style="display: flex; flex-direction: column; gap: 1.5rem;" data-role="history-job-details" data-job-id={@selected_job.id}>
          <div>
            <button type="button" phx-click="back" phx-target={@myself} class="oc-btn oc-btn-secondary" data-role="history-back">
              &larr; Back to history
            </button>
          </div>

          <.job_args_card job={@selected_job} />

          <div class="oc-card">
            <div class="oc-job-header">
              <h3 class="oc-text-sm" style="font-weight: 600; color: var(--oc-gray-900);">Execution Details</h3>
            </div>
            <div class="oc-job-args-grid">
              <div>
                <dt class="oc-job-arg-title">Queue</dt>
                <dd class="oc-job-arg-value"><%= @selected_job.queue %></dd>
              </div>
              <div>
                <dt class="oc-job-arg-title">Attempts</dt>
                <dd class="oc-job-arg-value"><%= @selected_job.attempt %> / <%= @selected_job.max_attempts %></dd>
              </div>
              <div>
                <dt class="oc-job-arg-title">Inserted At</dt>
                <dd class="oc-job-arg-value"><%= format_datetime(@selected_job.inserted_at) %></dd>
              </div>
              <div>
                <dt class="oc-job-arg-title">Attempted At</dt>
                <dd class="oc-job-arg-value"><%= format_datetime(@selected_job.attempted_at) %></dd>
              </div>
              <div>
                <dt class="oc-job-arg-title">
                  <%= if @selected_job.state == :retryable, do: "Next Retry At", else: "Finished At" %>
                </dt>
                <dd class="oc-job-arg-value">
                  <%= if @selected_job.state == :retryable,
                    do: format_datetime(@selected_job.scheduled_at),
                    else: format_datetime(finished_at(@selected_job)) %>
                </dd>
              </div>
            </div>
          </div>

          <%= if @selected_job.errors != [] do %>
            <div style="display: flex; flex-direction: column; gap: 1rem;">
              <h3 class="oc-text-sm" style="font-weight: 600; color: var(--oc-gray-900); padding-left: 0.25rem;">Errors</h3>
              <%= for error <- Enum.reverse(@selected_job.errors) do %>
                <div class="oc-error-block" data-role="history-job-error">
                  <div class="oc-error-meta">
                    Attempt <%= error["attempt"] %> &middot; <%= error["at"] %>
                  </div>
                  <pre class="oc-error-message"><%= error["error"] %></pre>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="oc-card">
          <div class="oc-job-header">
            <h3 class="oc-text-sm" style="font-weight: 600; color: var(--oc-gray-900);">Previous Runs</h3>
            <button type="button" phx-click="refresh" phx-target={@myself} class="oc-btn oc-btn-secondary" data-role="history-refresh">
              Refresh
            </button>
          </div>

          <%= if @jobs == [] do %>
            <p class="oc-history-empty" data-role="history-empty">No previous runs yet.</p>
          <% else %>
            <table class="oc-history-table">
              <thead>
                <tr>
                  <th>Job</th>
                  <th>State</th>
                  <th>Arguments</th>
                  <th>Attempts</th>
                  <th>Finished At</th>
                </tr>
              </thead>
              <tbody>
                <%= for job <- @jobs do %>
                  <tr
                    phx-click="select_job"
                    phx-value-id={job.id}
                    phx-target={@myself}
                    data-role="history-row"
                    data-job-id={job.id}
                  >
                    <td class="oc-font-mono">#<%= job.id %></td>
                    <td><.state_badge state={job.state} /></td>
                    <td class="oc-history-args oc-font-mono" title={format_args(job.args)}>
                      <%= format_args(job.args) %>
                    </td>
                    <td><%= job.attempt %> / <%= job.max_attempts %></td>
                    <td><%= format_datetime(finished_at(job)) %></td>
                  </tr>
                <% end %>
              </tbody>
            </table>

            <%= if @has_more do %>
              <div class="oc-history-footer">
                <button type="button" phx-click="load_more" phx-target={@myself} class="oc-btn oc-btn-secondary" data-role="history-load-more">
                  Load more
                </button>
              </div>
            <% end %>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def update(%{refresh: true}, socket) do
    if socket.assigns.selected do
      {:ok, load_jobs(socket)}
    else
      {:ok, socket}
    end
  end

  @impl true
  def update(assigns, socket) do
    was_selected = socket.assigns[:selected] == true

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:jobs, fn -> [] end)
      |> assign_new(:has_more, fn -> false end)
      |> assign_new(:limit, fn -> @page_size end)
      |> assign_new(:selected_job_id, fn -> nil end)

    if socket.assigns.selected and not was_selected do
      {:ok, load_jobs(socket)}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_event("select_job", %{"id" => id}, socket) do
    {:noreply, assign(socket, selected_job_id: String.to_integer(id))}
  end

  @impl true
  def handle_event("back", _params, socket) do
    {:noreply, assign(socket, selected_job_id: nil)}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, load_jobs(socket)}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    {:noreply, socket |> assign(limit: socket.assigns.limit + @page_size) |> load_jobs()}
  end

  defp load_jobs(socket) do
    limit = socket.assigns.limit
    jobs = ObanChore.list_job_history(socket.assigns.chore.module, limit: limit)

    assign(socket, jobs: jobs, has_more: length(jobs) == limit)
  end

  defp finished_at(job) do
    job.completed_at || job.discarded_at || job.cancelled_at || job.attempted_at
  end

  defp format_args(args) when map_size(args) == 0, do: "—"

  defp format_args(args) do
    Enum.map_join(args, ", ", fn {key, value} -> "#{key}: #{inspect(value)}" end)
  end
end
