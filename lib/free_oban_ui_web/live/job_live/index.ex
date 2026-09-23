defmodule FreeObanUiWeb.JobLive.Index do
  use FreeObanUiWeb, :live_view

  import FreeObanUiWeb.JobComponents

  alias FreeObanUi.Jobs

  @refresh_interval :timer.seconds(2)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: schedule_refresh()

    {:ok, assign(socket, page_title: "Jobs", states: Jobs.states())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = %{
      state: Enum.find(socket.assigns.states, &(&1 == params["state"])),
      queue: presence(params["queue"])
    }

    {:noreply, socket |> assign(:filters, filters) |> load_jobs()}
  end

  @impl true
  def handle_event("filter", %{"queue" => queue}, socket) do
    filters = %{socket.assigns.filters | queue: presence(queue)}

    {:noreply, push_patch(socket, to: jobs_path(filters))}
  end

  def handle_event("retry", %{"id" => id}, socket) do
    socket =
      with_job(socket, id, fn job ->
        :ok = Jobs.retry_job(job)
        put_flash(socket, :info, "Job #{job.id} will be retried")
      end)

    {:noreply, load_jobs(socket)}
  end

  def handle_event("cancel", %{"id" => id}, socket) do
    socket =
      with_job(socket, id, fn job ->
        :ok = Jobs.cancel_job(job)
        put_flash(socket, :info, "Job #{job.id} cancelled")
      end)

    {:noreply, load_jobs(socket)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    schedule_refresh()

    {:noreply, load_jobs(socket)}
  end

  defp load_jobs(socket) do
    %{state: state, queue: queue} = socket.assigns.filters

    assign(socket,
      jobs: Jobs.list_jobs(state: state, queue: queue),
      counts: Jobs.count_jobs_by_state(queue: queue),
      queues: Jobs.list_queues()
    )
  end

  defp with_job(socket, id, fun) do
    case Jobs.get_job(id) do
      nil -> put_flash(socket, :error, "Job #{id} no longer exists")
      job -> fun.(job)
    end
  end

  defp schedule_refresh, do: Process.send_after(self(), :refresh, @refresh_interval)

  defp jobs_path(filters) do
    ~p"/jobs?#{for {key, value} <- filters, value, do: {key, value}}"
  end

  defp presence(value) when value in [nil, ""], do: nil
  defp presence(value), do: value

  defp total(counts, nil), do: counts |> Map.values() |> Enum.sum()
  defp total(counts, state), do: Map.fetch!(counts, state)

  defp state_tab_class(active?) do
    [
      "rounded-lg px-3 py-1.5 text-sm font-semibold leading-6",
      if(active?, do: "bg-zinc-900 text-white", else: "text-zinc-600 hover:bg-zinc-100")
    ]
  end
end
