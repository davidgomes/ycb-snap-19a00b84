defmodule ObanChoreWeb.HistoryComponent do
  @moduledoc false
  use Phoenix.Component

  attr(:jobs, :list, required: true)
  attr(:selected, :boolean, default: false)

  def history(assigns) do
    ~H"""
    <div class={if @selected, do: "oc-block", else: "oc-hidden"} data-role="history">
      <div class="oc-card">
        <%= if @jobs == [] do %>
          <div class="oc-card-body">
            <p class="oc-text-sm oc-text-gray-500" style="font-style: italic;">No finished executions yet.</p>
          </div>
        <% else %>
          <table class="oc-history-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>State</th>
                <th>Arguments</th>
                <th>Attempts</th>
                <th>Finished At</th>
              </tr>
            </thead>
            <tbody>
              <%= for job <- @jobs do %>
                <tr data-role="history-row" data-job-id={job.id}>
                  <td class="oc-font-mono"><%= job.id %></td>
                  <td>
                    <span class="oc-badge" style={ObanChoreWeb.JobComponent.state_style(job.state)}>
                      <%= String.capitalize(to_string(job.state)) %>
                    </span>
                  </td>
                  <td class="oc-font-mono oc-history-args" title={inspect(job.args)}>
                    <%= if map_size(job.args) > 0 do %>
                      <%= Enum.map_join(job.args, ", ", fn {k, v} -> "#{k}: #{inspect(v)}" end) %>
                    <% else %>
                      <span class="oc-text-gray-500" style="font-style: italic;">None</span>
                    <% end %>
                  </td>
                  <td><%= job.attempt %>/<%= job.max_attempts %></td>
                  <td class="oc-text-gray-500"><%= format_finished_at(job) %></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_finished_at(job) do
    case job.completed_at || job.discarded_at || job.cancelled_at do
      nil -> "-"
      datetime -> Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
    end
  end
end
