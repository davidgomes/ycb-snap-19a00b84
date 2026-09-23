defmodule ObanChoreWeb.JobComponent do
  @moduledoc false
  use Phoenix.LiveComponent
  import ObanChoreWeb.CoreComponents

  @impl true
  def render(assigns) do
    ~H"""
    <div class={if @selected, do: "oc-block", else: "oc-hidden"} data-role="job-details" data-job-id={@job.id}>
      <div style="display: flex; flex-direction: column; gap: 1.5rem;">
        <.job_args_card job={@job} />

        <div style="display: flex; flex-direction: column; gap: 1rem;">
          <h3 class="oc-text-sm" style="font-weight: 600; color: var(--oc-gray-900); padding-left: 0.25rem;">Execution Logs</h3>

          <div class={[
            "oc-log-container",
            if(@logs == [], do: "oc-flex oc-items-center oc-justify-center oc-text-gray-500", else: "")
          ]} style={if(@logs == [], do: "font-style: italic;", else: "")}>
            <%= if @logs == [] do %>
              <%= if @job.state == :executing do %>
                Waiting for logs...
              <% else %>
                No logs yet.
              <% end %>
            <% else %>
              <div style="display: flex; flex-direction: column-reverse; gap: 0.25rem;">
                <%= for log <- @logs do %>
                  <div class="oc-log-line">
                    <span class="oc-log-prompt">$</span>
                    <span class="oc-log-content"><%= log %></span>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def update(%{new_log: message}, socket) do
    {:ok, assign(socket, logs: [message | socket.assigns.logs])}
  end

  @impl true
  def update(%{new_state: state}, socket) do
    {:ok, assign(socket, job: %{socket.assigns.job | state: state})}
  end

  @impl true
  def update(assigns, socket) do
    if socket.assigns[:job] == nil do
      {:ok,
       socket
       |> assign(assigns)
       |> assign(logs: [])}
    else
      {:ok, assign(socket, assigns)}
    end
  end
end
