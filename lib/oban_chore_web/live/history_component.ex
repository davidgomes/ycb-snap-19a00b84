defmodule ObanChoreWeb.HistoryComponent do
  @moduledoc false
  use Phoenix.LiveComponent
  import ObanChoreWeb.CoreComponents

  @per_page 20

  @impl true
  def render(assigns) do
    ~H"""
    <div class={if @selected, do: "oc-block", else: "oc-hidden"} data-role="history">
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
          <p
            class="oc-text-sm oc-text-gray-500"
            style="font-style: italic; padding: 2rem 1.5rem; text-align: center;"
            data-role="history-empty"
          >
            No previous runs found.
          </p>
        <% else %>
          <div style="overflow-x: auto;">
            <table class="oc-table">
              <thead>
                <tr>
                  <th>Job</th>
                  <th>State</th>
                  <th>Arguments</th>
                  <th>Attempt</th>
                  <th>Inserted</th>
                  <th>Finished</th>
                </tr>
              </thead>
              <tbody>
                <%= for job <- @jobs do %>
                  <tr
                    phx-click="open_job"
                    phx-value-id={job.id}
                    phx-target={@myself}
                    data-role="history-row"
                    data-job-id={job.id}
                    class="oc-table-row--clickable"
                  >
                    <td class="oc-font-mono">#<%= job.id %></td>
                    <td><.state_badge state={job.state} /></td>
                    <td class="oc-font-mono oc-table-cell--truncate" title={format_args(job.args)}>
                      <%= format_args(job.args) %>
                    </td>
                    <td><%= job.attempt %> / <%= job.max_attempts %></td>
                    <td><%= format_datetime(job.inserted_at) %></td>
                    <td><%= format_datetime(finished_at(job)) %></td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>

        <%= if @page > 1 or @has_more? do %>
          <div class="oc-history-pagination">
            <span class="oc-text-sm oc-text-gray-500">Page <%= @page %></span>
            <div class="oc-flex oc-gap-2">
              <button
                type="button"
                phx-click="prev_page"
                phx-target={@myself}
                disabled={@page == 1}
                data-role="history-prev-page"
                class="oc-btn oc-btn-secondary"
              >
                Newer
              </button>
              <button
                type="button"
                phx-click="next_page"
                phx-target={@myself}
                disabled={not @has_more?}
                data-role="history-next-page"
                class="oc-btn oc-btn-secondary"
              >
                Older
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    was_selected? = Map.get(socket.assigns, :selected, false)

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:page, fn -> 1 end)
      |> assign_new(:jobs, fn -> [] end)
      |> assign_new(:has_more?, fn -> false end)

    if socket.assigns.selected and not was_selected? do
      {:ok, load_page(socket, socket.assigns.page)}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, load_page(socket, socket.assigns.page)}
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    {:noreply, load_page(socket, max(socket.assigns.page - 1, 1))}
  end

  @impl true
  def handle_event("next_page", _params, socket) do
    if socket.assigns.has_more? do
      {:noreply, load_page(socket, socket.assigns.page + 1)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open_job", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)

    case Enum.find(socket.assigns.jobs, &(&1.id == id)) do
      nil -> :ok
      job -> send(self(), {:open_history_job, job, socket.assigns.chore.module})
    end

    {:noreply, socket}
  end

  defp load_page(socket, page) do
    jobs =
      ObanChore.list_job_history(socket.assigns.chore.module,
        limit: @per_page + 1,
        offset: (page - 1) * @per_page
      )

    if jobs == [] and page > 1 do
      load_page(socket, page - 1)
    else
      assign(socket,
        page: page,
        jobs: Enum.take(jobs, @per_page),
        has_more?: length(jobs) > @per_page
      )
    end
  end

  defp finished_at(job) do
    job.completed_at || job.discarded_at || job.cancelled_at
  end

  defp format_args(args) when map_size(args) == 0, do: "—"

  defp format_args(args) do
    Enum.map_join(args, ", ", fn {key, value} -> "#{key}: #{inspect(value)}" end)
  end
end
