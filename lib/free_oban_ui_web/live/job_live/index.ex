defmodule FreeObanUiWeb.JobLive.Index do
  use FreeObanUiWeb, :live_view

  import FreeObanUiWeb.JobLive.Components

  alias FreeObanUi.Jobs

  @per_page 20
  @refresh_interval :timer.seconds(2)

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
     |> assign(state: state, page: parse_page(params["page"]))
     |> load_jobs()}
  end

  @impl true
  def handle_event(action, %{"id" => id}, socket) when action in ~w(retry cancel delete) do
    {_result, socket} = apply_action(socket, action, id)

    {:noreply, load_jobs(socket)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    schedule_refresh()

    {:noreply, load_jobs(socket)}
  end

  defp schedule_refresh, do: Process.send_after(self(), :refresh, @refresh_interval)

  defp load_jobs(socket) do
    %{state: state, page: page} = socket.assigns

    counts = Jobs.count_jobs_by_state()
    total = if state, do: counts[state], else: counts |> Map.values() |> Enum.sum()
    total_pages = max(ceil(total / @per_page), 1)
    page = min(page, total_pages)

    assign(socket,
      counts: counts,
      total: total,
      page: page,
      total_pages: total_pages,
      jobs: Jobs.list_jobs(state: state, limit: @per_page, offset: (page - 1) * @per_page),
      now: DateTime.utc_now()
    )
  end

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {page, ""} when page > 0 -> page
      _ -> 1
    end
  end

  defp parse_page(_page), do: 1

  defp jobs_path(state, page) do
    params = Enum.reject([state: state, page: page > 1 && page], fn {_key, value} -> !value end)

    ~p"/jobs?#{params}"
  end

  defp args_preview(args), do: Jason.encode!(args)

  attr :state, :string, default: nil
  attr :current, :string, default: nil
  attr :count, :integer, required: true
  slot :inner_block, required: true

  defp state_tab(assigns) do
    ~H"""
    <.link
      id={"state-tab-#{@state || "all"}"}
      patch={jobs_path(@state, 1)}
      aria-current={@state == @current && "page"}
      class={[
        "flex items-center gap-2 rounded-lg px-3 py-1.5 text-sm font-semibold leading-6",
        if(@state == @current,
          do: "bg-zinc-900 text-white",
          else: "text-zinc-700 hover:bg-zinc-100"
        )
      ]}
    >
      <%= render_slot(@inner_block) %>
      <span class={[
        "rounded-full px-2 text-xs leading-5",
        if(@state == @current, do: "bg-white/20", else: "bg-zinc-100 text-zinc-600")
      ]}>
        <%= @count %>
      </span>
    </.link>
    """
  end
end
