defmodule FreeObanUiWeb.JobLive.Index do
  use FreeObanUiWeb, :live_view

  import FreeObanUiWeb.JobLive.Components

  alias FreeObanUi.Jobs

  @per_page 50
  @refresh_interval :timer.seconds(1)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: schedule_refresh()

    {:ok, assign(socket, :page_title, "Jobs")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    state = if params["state"] in Jobs.states(), do: params["state"]

    {:noreply,
     socket
     |> assign(state: state, limit: @per_page)
     |> load_jobs()}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    {:noreply,
     socket
     |> update(:limit, &(&1 + @per_page))
     |> load_jobs()}
  end

  @impl true
  def handle_info(:refresh, socket) do
    schedule_refresh()

    {:noreply, load_jobs(socket)}
  end

  defp load_jobs(socket) do
    %{state: state, limit: limit} = socket.assigns
    counts = Jobs.count_jobs_by_state()
    total = counts |> Map.values() |> Enum.sum()

    assign(socket,
      counts: counts,
      total: total,
      matching: if(state, do: counts[state], else: total),
      jobs: Jobs.list_jobs(state: state, limit: limit)
    )
  end

  defp schedule_refresh, do: Process.send_after(self(), :refresh, @refresh_interval)

  attr :state, :string, default: nil
  attr :current, :string, default: nil
  attr :count, :integer, required: true

  defp state_filter(assigns) do
    ~H"""
    <.link
      id={"state-filter-#{@state || "all"}"}
      patch={if @state, do: ~p"/jobs?state=#{@state}", else: ~p"/jobs"}
      aria-current={@state == @current && "page"}
      class={[
        "rounded-full px-3 py-1 text-sm font-medium leading-6 ring-1 ring-inset",
        if(@state == @current,
          do: "bg-zinc-900 text-white ring-zinc-900",
          else: "text-zinc-700 ring-zinc-200 hover:bg-zinc-50"
        )
      ]}
    >
      <%= if @state, do: String.capitalize(@state), else: "All" %>
      <span class={["ml-1", @state != @current && "text-zinc-400"]}><%= @count %></span>
    </.link>
    """
  end
end
