defmodule FreeObanUiWeb.JobLive.Index do
  use FreeObanUiWeb, :live_view

  import FreeObanUiWeb.JobComponents

  alias FreeObanUi.Jobs

  @refresh_interval :timer.seconds(2)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(@refresh_interval, self(), :refresh)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    state = if params["state"] in Jobs.states(), do: params["state"]

    {:noreply,
     socket
     |> assign(:state, state)
     |> assign(:page_title, if(state, do: "Jobs · #{state}", else: "Jobs"))
     |> load_jobs()}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, load_jobs(socket)}
  end

  defp load_jobs(socket) do
    counts = Jobs.count_jobs_by_state()

    socket
    |> assign(:counts, counts)
    |> assign(:total, counts |> Map.values() |> Enum.sum())
    |> assign(:jobs, Jobs.list_jobs(state: socket.assigns.state))
  end

  attr :active, :boolean, required: true
  attr :patch, :string, required: true
  attr :count, :integer, required: true
  attr :rest, :global
  slot :inner_block, required: true

  defp state_tab(assigns) do
    ~H"""
    <.link
      patch={@patch}
      class={[
        "inline-flex items-center gap-2 rounded-lg px-3 py-1 text-sm font-semibold leading-6",
        if(@active,
          do: "bg-zinc-900 text-white",
          else: "bg-zinc-100 text-zinc-700 hover:bg-zinc-200/80"
        )
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
      <span class="text-xs font-normal opacity-75"><%= @count %></span>
    </.link>
    """
  end
end
