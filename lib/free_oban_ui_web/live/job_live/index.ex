defmodule FreeObanUiWeb.JobLive.Index do
  use FreeObanUiWeb, :live_view

  import Ecto.Query

  alias FreeObanUi.Repo

  @states ~w(all available scheduled executing retryable completed discarded cancelled)
  @per_page 20

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    state = valid_state(params["state"])
    queue = present(params["queue"])
    page = params["page"] |> to_integer(1) |> max(1)

    jobs = list_jobs(state, queue, page)
    queues = list_queues()

    socket =
      socket
      |> assign(:state, state)
      |> assign(:queue, queue)
      |> assign(:page, page)
      |> assign(:queues, queues)
      |> assign(:states, @states)
      |> assign(:jobs, jobs)
      |> assign(:has_more?, length(jobs) == @per_page)

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", params, socket) do
    state = valid_state(params["state"])
    queue = present(params["queue"])

    {:noreply, push_patch(socket, to: path(state, queue, 1))}
  end

  @impl true
  def handle_event("cancel", %{"id" => id}, socket) do
    id
    |> String.to_integer()
    |> Oban.cancel_job()

    {:noreply, refresh(socket)}
  end

  @impl true
  def handle_event("retry", %{"id" => id}, socket) do
    id
    |> String.to_integer()
    |> Oban.retry_job()

    {:noreply, refresh(socket)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    id = String.to_integer(id)

    from(j in Oban.Job, where: j.id == ^id)
    |> Repo.delete_all()

    {:noreply, refresh(socket)}
  end

  defp refresh(socket) do
    jobs = list_jobs(socket.assigns.state, socket.assigns.queue, socket.assigns.page)

    socket
    |> assign(:jobs, jobs)
    |> assign(:has_more?, length(jobs) == @per_page)
  end

  defp list_jobs(state, queue, page) do
    Oban.Job
    |> filter_by_state(state)
    |> filter_by_queue(queue)
    |> order_by(desc: :id)
    |> limit(^@per_page)
    |> offset(^((page - 1) * @per_page))
    |> Repo.all()
  end

  defp filter_by_state(query, "all"), do: query
  defp filter_by_state(query, state), do: where(query, [j], j.state == ^state)

  defp filter_by_queue(query, nil), do: query
  defp filter_by_queue(query, queue), do: where(query, [j], j.queue == ^queue)

  defp list_queues do
    Oban.Job
    |> distinct(true)
    |> select([j], j.queue)
    |> order_by(asc: :queue)
    |> Repo.all()
  end

  defp valid_state(state) when state in @states, do: state
  defp valid_state(_), do: "all"

  defp present(nil), do: nil
  defp present(""), do: nil
  defp present(value), do: value

  defp to_integer(nil, default), do: default

  defp to_integer(value, default) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp path(state, queue, page) do
    ~p"/oban/jobs?#{%{state: state, queue: queue, page: page}}"
  end

  defp state_badge_class("completed"), do: "bg-green-100 text-green-800"
  defp state_badge_class("executing"), do: "bg-blue-100 text-blue-800"
  defp state_badge_class("available"), do: "bg-zinc-100 text-zinc-800"
  defp state_badge_class("scheduled"), do: "bg-yellow-100 text-yellow-800"
  defp state_badge_class("retryable"), do: "bg-orange-100 text-orange-800"
  defp state_badge_class("discarded"), do: "bg-red-100 text-red-800"
  defp state_badge_class("cancelled"), do: "bg-zinc-200 text-zinc-600"
  defp state_badge_class(_), do: "bg-zinc-100 text-zinc-800"
end
