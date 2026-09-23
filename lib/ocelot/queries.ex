defmodule Ocelot.Queries do
  @moduledoc false

  import Ecto.Query

  alias Oban.{Job, Repo}

  @states ~w(available scheduled executing retryable completed discarded cancelled)

  def states, do: @states

  def state_counts(conf) do
    counts =
      conf
      |> Repo.all(from(j in Job, group_by: j.state, select: {j.state, count(j.id)}))
      |> Map.new()

    Enum.map(@states, &{&1, Map.get(counts, &1, 0)})
  end

  def queue_counts(conf) do
    Repo.all(
      conf,
      from(j in Job, group_by: j.queue, order_by: j.queue, select: {j.queue, count(j.id)})
    )
  end

  def list_jobs(conf, filters, limit) do
    query =
      Job
      |> filter_by(:state, filters[:state])
      |> filter_by(:queue, filters[:queue])
      |> order_by(desc: :id)
      |> limit(^limit)

    Repo.all(conf, query)
  end

  def get_job(conf, id) do
    Repo.one(conf, from(j in Job, where: j.id == ^id))
  end

  defp filter_by(query, _field, nil), do: query
  defp filter_by(query, field, value), do: where(query, [j], field(j, ^field) == ^value)
end
