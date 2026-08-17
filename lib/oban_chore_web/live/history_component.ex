defmodule ObanChoreWeb.HistoryComponent do
  @moduledoc false
  use Phoenix.LiveComponent
  import ObanChoreWeb.CoreComponents

  @impl true
  def render(assigns) do
    ~H"""
    <div class={if @selected, do: "oc-block", else: "oc-hidden"} data-role="chore-history" data-chore-module={to_string(@chore.module)}>
      <div class="oc-container" style="display: flex; flex-direction: column; gap: 1.5rem;">
        <div class="oc-card">
          <div class="oc-history-header">
            <div>
              <h3 class="oc-text-sm" style="font-weight: 600; color: var(--oc-gray-900);">Previous Runs</h3>
              <p class="oc-text-xs oc-text-gray-500 oc-mt-2">Past executions for <%= @chore.name %></p>
            </div>
            <button
              type="button"
              phx-click="refresh"
              phx-target={@myself}
              data-role="refresh-history"
              class="oc-btn oc-btn-secondary"
            >
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" style="width: 1rem; height: 1rem; margin-right: 0.25rem;">
                <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0 0 13.803-3.7M4.031 9.865a8.25 8.25 0 0 1 13.803-3.7l3.181 3.182m0-4.991v4.99" />
              </svg>
              Refresh
            </button>
          </div>

          <%= if @jobs == [] do %>
            <div class="oc-empty-history">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" style="width: 2.5rem; height: 2.5rem; color: var(--oc-gray-400); margin-bottom: 0.5rem;">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
              </svg>
              <p class="oc-text-sm oc-text-gray-500">No previous runs found for this chore.</p>
            </div>
          <% else %>
            <div class="oc-table-wrapper">
              <table class="oc-table" data-role="history-table">
                <thead>
                  <tr>
                    <th
                      phx-click="sort"
                      phx-value-by="id"
                      phx-target={@myself}
                      class="oc-th oc-sortable"
                    >
                      <div class="oc-th-content">
                        <span>Job ID</span>
                        <%= if @sort_by == :id do %>
                          <span><%= if @sort_dir == :asc, do: "↑", else: "↓" %></span>
                        <% end %>
                      </div>
                    </th>
                    <th class="oc-th">State</th>
                    <th class="oc-th">Arguments</th>
                    <th
                      phx-click="sort"
                      phx-value-by="attempted_at"
                      phx-target={@myself}
                      class="oc-th oc-sortable"
                    >
                      <div class="oc-th-content">
                        <span>Attempted At</span>
                        <%= if @sort_by == :attempted_at do %>
                          <span><%= if @sort_dir == :asc, do: "↑", else: "↓" %></span>
                        <% end %>
                      </div>
                    </th>
                    <th class="oc-th">Duration</th>
                    <th class="oc-th" style="text-align: right;">Action</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for job <- @jobs do %>
                    <tr class="oc-tr" data-role="history-row" data-job-id={job.id}>
                      <td class="oc-td oc-font-mono oc-text-sm">
                        #<%= job.id %>
                      </td>
                      <td class="oc-td">
                        <.state_badge state={job.state} />
                      </td>
                      <td class="oc-td oc-text-xs oc-font-mono" style="max-width: 15rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;" title={inspect(job.args)}>
                        <%= format_args_summary(job.args) %>
                      </td>
                      <td class="oc-td oc-text-sm oc-text-gray-500">
                        <%= format_relative_time(job.attempted_at || job.inserted_at) %>
                      </td>
                      <td class="oc-td oc-text-sm oc-text-gray-500">
                        <%= format_duration(job) %>
                      </td>
                      <td class="oc-td" style="text-align: right;">
                        <button
                          type="button"
                          phx-click="view_job"
                          phx-value-id={job.id}
                          data-role="view-job"
                          data-job-id={job.id}
                          class="oc-btn-link"
                        >
                          View Details →
                        </button>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    if socket.assigns[:chore] == nil or socket.assigns[:chore].module != assigns.chore.module do
      sort_by = :id
      sort_dir = :desc
      limit = 20
      jobs = ObanChore.list_previous_runs(assigns.chore.module, Oban, limit, sort_by, sort_dir)

      {:ok,
       socket
       |> assign(assigns)
       |> assign(
         jobs: jobs,
         sort_by: sort_by,
         sort_dir: sort_dir,
         limit: limit
       )}
    else
      # If selected transitioned to true, refresh list
      prev_selected = socket.assigns[:selected]
      new_selected = assigns[:selected]

      socket = assign(socket, assigns)

      if not prev_selected and new_selected do
        jobs =
          ObanChore.list_previous_runs(
            socket.assigns.chore.module,
            Oban,
            socket.assigns.limit,
            socket.assigns.sort_by,
            socket.assigns.sort_dir
          )

        {:ok, assign(socket, jobs: jobs)}
      else
        {:ok, socket}
      end
    end
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    jobs =
      ObanChore.list_previous_runs(
        socket.assigns.chore.module,
        Oban,
        socket.assigns.limit,
        socket.assigns.sort_by,
        socket.assigns.sort_dir
      )

    {:noreply, assign(socket, jobs: jobs)}
  end

  @impl true
  def handle_event("sort", %{"by" => by_str}, socket) do
    by = String.to_existing_atom(by_str)

    {sort_by, sort_dir} =
      if socket.assigns.sort_by == by do
        new_dir = if socket.assigns.sort_dir == :asc, do: :desc, else: :asc
        {by, new_dir}
      else
        {by, :desc}
      end

    jobs =
      ObanChore.list_previous_runs(
        socket.assigns.chore.module,
        Oban,
        socket.assigns.limit,
        sort_by,
        sort_dir
      )

    {:noreply, assign(socket, jobs: jobs, sort_by: sort_by, sort_dir: sort_dir)}
  end

  defp format_args_summary(args) when is_map(args) and map_size(args) > 0 do
    inspect(args)
  end

  defp format_args_summary(_), do: "None"
end
