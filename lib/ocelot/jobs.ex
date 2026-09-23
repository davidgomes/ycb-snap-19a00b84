defmodule Ocelot.Jobs do
  @moduledoc false

  import Ecto.Query

  alias Oban.{Job, Repo}

  @states Enum.map(Job.states(), &Atom.to_string/1)
  @per_page 20

  def states, do: @states

  def per_page, do: @per_page

  @doc """
  Builds sanitized list filters from request query params.
  """
  def parse_filters(params) when is_map(params) do
    %{
      state: parse_state(params["state"]),
      queue: parse_queue(params["queue"]),
      page: parse_page(params["page"])
    }
  end

  defp parse_state(state) when state in @states, do: state
  defp parse_state(_state), do: nil

  defp parse_queue(queue) when is_binary(queue) and queue != "", do: queue
  defp parse_queue(_queue), do: nil

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {page, ""} when page > 0 -> page
      _ -> 1
    end
  end

  defp parse_page(_page), do: 1

  @doc """
  Returns a page of jobs matching the filters and whether a following page exists.
  """
  def list(conf, %{page: page} = filters) do
    jobs =
      Job
      |> filter(filters)
      |> order(filters.state)
      |> limit(^(@per_page + 1))
      |> offset(^((page - 1) * @per_page))
      |> then(&Repo.all(conf, &1))

    {Enum.take(jobs, @per_page), length(jobs) > @per_page}
  end

  @doc """
  Counts jobs per state, respecting the queue filter.
  """
  def count_by_state(conf, filters) do
    Job
    |> filter(%{filters | state: nil})
    |> group_by([j], j.state)
    |> select([j], {j.state, count(j.id)})
    |> then(&Repo.all(conf, &1))
    |> Map.new()
  end

  @doc """
  Counts jobs per queue, respecting the state filter.
  """
  def count_by_queue(conf, filters) do
    Job
    |> filter(%{filters | queue: nil})
    |> group_by([j], j.queue)
    |> order_by([j], j.queue)
    |> select([j], {j.queue, count(j.id)})
    |> then(&Repo.all(conf, &1))
  end

  def get(conf, id) when is_integer(id), do: Repo.get(conf, Job, id)

  defp filter(query, filters) do
    query
    |> where_state(filters.state)
    |> where_queue(filters.queue)
  end

  defp where_state(query, nil), do: query
  defp where_state(query, state), do: where(query, [j], j.state == ^state)

  defp where_queue(query, nil), do: query
  defp where_queue(query, queue), do: where(query, [j], j.queue == ^queue)

  defp order(query, "available"),
    do: order_by(query, [j], asc: j.priority, asc: j.scheduled_at, asc: j.id)

  defp order(query, "scheduled"), do: order_by(query, [j], asc: j.scheduled_at, asc: j.id)
  defp order(query, "retryable"), do: order_by(query, [j], asc: j.scheduled_at, asc: j.id)
  defp order(query, "executing"), do: order_by(query, [j], desc: j.attempted_at, desc: j.id)
  defp order(query, "completed"), do: order_by(query, [j], desc: j.completed_at, desc: j.id)
  defp order(query, "discarded"), do: order_by(query, [j], desc: j.discarded_at, desc: j.id)
  defp order(query, "cancelled"), do: order_by(query, [j], desc: j.cancelled_at, desc: j.id)
  defp order(query, _state), do: order_by(query, [j], desc: j.id)
end
