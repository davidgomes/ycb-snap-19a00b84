defmodule ObanChoreWeb.HistoryComponent do
  @moduledoc false
  use Phoenix.LiveComponent
  import ObanChoreWeb.CoreComponents

  @impl true
  def render(assigns) do
    ~H"""
    <div class={if @selected, do: "oc-block", else: "oc-hidden"} data-role="history">
      <div class="oc-card">
        <div class="oc-job-header">
          <h3 class="oc-text-sm" style="font-weight: 600; color: var(--oc-gray-900);">Previous Runs</h3>
          <span class="oc-history-meta">Most recent first</span>
        </div>

        <%= if @jobs == [] do %>
          <p class="oc-history-empty" data-role="history-empty">No previous runs yet.</p>
        <% else %>
          <ul class="oc-history-list">
            <%= for job <- @jobs do %>
              <li class="oc-history-item" data-role="history-item" data-job-id={job.id}>
                <div class="oc-history-item-header">
                  <div class="oc-flex oc-items-center oc-gap-2">
                    <span class="oc-history-job-id">Job #<%= job.id %></span>
                    <.state_badge state={job.state} />
                  </div>
                  <div class="oc-history-meta">
                    <span>Attempt <%= job.attempt %>/<%= job.max_attempts %></span>
                    <span><%= format_timestamp(finished_at(job)) %></span>
                  </div>
                </div>

                <%= if map_size(job.args) > 0 do %>
                  <div class="oc-history-args">
                    <%= for {key, value} <- job.args do %>
                      <span class="oc-history-arg" title={inspect(value)}>
                        <span class="oc-history-arg-key"><%= key %></span>
                        <span class="oc-history-arg-value oc-font-mono"><%= inspect(value) %></span>
                      </span>
                    <% end %>
                  </div>
                <% else %>
                  <p class="oc-history-meta" style="margin: 0; font-style: italic;">No arguments provided.</p>
                <% end %>

                <%= if error = last_error(job) do %>
                  <p class="oc-history-error oc-font-mono" title={error} data-role="history-error">
                    <%= error |> String.split("\n", parts: 2) |> hd() %>
                  </p>
                <% end %>
              </li>
            <% end %>
          </ul>
        <% end %>
      </div>
    </div>
    """
  end

  defp finished_at(job) do
    job.completed_at || job.discarded_at || job.cancelled_at || job.attempted_at
  end

  defp format_timestamp(nil), do: "—"
  defp format_timestamp(datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")

  defp last_error(%{state: :completed}), do: nil
  defp last_error(%{errors: [_ | _] = errors}), do: errors |> List.last() |> Map.get("error")
  defp last_error(_job), do: nil
end
