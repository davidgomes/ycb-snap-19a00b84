defmodule ObanChoreWeb.HistoryComponent do
  @moduledoc false
  use Phoenix.LiveComponent

  import ObanChoreWeb.CoreComponents,
    only: [job_state_style: 1, format_datetime: 1, format_duration: 2]

  @page_size 20

  @impl true
  def render(assigns) do
    ~H"""
    <div data-role="history" data-chore-module={to_string(@chore.module)}>
      <div class="oc-card">
        <div class="oc-job-header">
          <h3 class="oc-text-sm" style="font-weight: 600; color: var(--oc-gray-900);">Previous Runs</h3>
          <button
            type="button"
            phx-click="refresh"
            phx-target={@myself}
            data-role="history-refresh"
            class="oc-btn oc-btn-secondary"
          >
            Refresh
          </button>
        </div>

        <%= if @jobs == [] do %>
          <p class="oc-history-empty" data-role="history-empty">
            No previous runs for this chore yet.
          </p>
        <% else %>
          <div class="oc-history-list">
            <div class="oc-history-row oc-history-row--header">
              <span>Job</span>
              <span>State</span>
              <span>Finished</span>
              <span>Duration</span>
              <span>Attempts</span>
            </div>
            <%= for job <- @jobs do %>
              <div data-role="history-item" data-job-id={job.id}>
                <button
                  type="button"
                  phx-click="toggle_job"
                  phx-value-id={job.id}
                  phx-target={@myself}
                  data-role="history-row"
                  data-job-id={job.id}
                  class={["oc-history-row", job.id in @expanded && "oc-history-row--expanded"]}
                >
                  <span class="oc-font-mono">#<%= job.id %></span>
                  <span>
                    <span class="oc-badge" style={job_state_style(job.state)}>
                      <%= String.capitalize(to_string(job.state)) %>
                    </span>
                  </span>
                  <span><%= format_datetime(finished_at(job)) %></span>
                  <span><%= format_duration(job.attempted_at, finished_at(job)) %></span>
                  <span><%= job.attempt %>/<%= job.max_attempts %></span>
                </button>

                <%= if job.id in @expanded do %>
                  <div class="oc-history-details" data-role="history-details" data-job-id={job.id}>
                    <div class="oc-job-args-grid">
                      <%= if map_size(job.args) > 0 do %>
                        <%= for {key, value} <- job.args do %>
                          <div>
                            <dt class="oc-job-arg-title"><%= key %></dt>
                            <dd class="oc-job-arg-value" title={inspect(value)}>
                              <%= inspect(value) %>
                            </dd>
                          </div>
                        <% end %>
                      <% else %>
                        <p class="oc-text-xs oc-text-gray-500" style="font-style: italic;">No arguments provided.</p>
                      <% end %>
                    </div>

                    <dl class="oc-history-meta">
                      <div>
                        <dt class="oc-job-arg-title">Inserted</dt>
                        <dd><%= format_datetime(job.inserted_at) %></dd>
                      </div>
                      <div>
                        <dt class="oc-job-arg-title">Started</dt>
                        <dd><%= format_datetime(job.attempted_at) %></dd>
                      </div>
                      <div>
                        <dt class="oc-job-arg-title">Finished</dt>
                        <dd><%= format_datetime(finished_at(job)) %></dd>
                      </div>
                    </dl>

                    <%= if last_error = List.last(job.errors || []) do %>
                      <div class="oc-history-error" data-role="history-error">
                        <div class="oc-job-arg-title">
                          Last error (attempt <%= last_error["attempt"] %>)
                        </div>
                        <pre><%= last_error["error"] %></pre>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

          <%= if @has_more do %>
            <div class="oc-history-footer">
              <button
                type="button"
                phx-click="load_more"
                phx-target={@myself}
                data-role="history-load-more"
                class="oc-btn oc-btn-secondary"
              >
                Load more
              </button>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def update(%{finished_job: job}, socket) do
    jobs =
      if Enum.any?(socket.assigns.jobs, &(&1.id == job.id)) do
        Enum.map(socket.assigns.jobs, fn existing ->
          if existing.id == job.id, do: job, else: existing
        end)
      else
        [job | socket.assigns.jobs]
      end

    {:ok, assign(socket, jobs: jobs)}
  end

  @impl true
  def update(assigns, socket) do
    if socket.assigns[:chore] == nil do
      {:ok,
       socket
       |> assign(assigns)
       |> assign(limit: @page_size, expanded: MapSet.new())
       |> load_jobs()}
    else
      {:ok, assign(socket, assigns)}
    end
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, load_jobs(socket)}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    {:noreply,
     socket
     |> assign(limit: socket.assigns.limit + @page_size)
     |> load_jobs()}
  end

  @impl true
  def handle_event("toggle_job", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    expanded = socket.assigns.expanded

    expanded =
      if MapSet.member?(expanded, id),
        do: MapSet.delete(expanded, id),
        else: MapSet.put(expanded, id)

    {:noreply, assign(socket, expanded: expanded)}
  end

  defp load_jobs(socket) do
    limit = socket.assigns.limit
    jobs = ObanChore.list_history_jobs(socket.assigns.chore.module, Oban, limit: limit + 1)

    assign(socket, jobs: Enum.take(jobs, limit), has_more: length(jobs) > limit)
  end

  defp finished_at(job) do
    job.completed_at || job.discarded_at || job.cancelled_at
  end
end
