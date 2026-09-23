defmodule Ocelot.Jobs do
  @moduledoc false

  import Ecto.Query

  alias Oban.{Job, Repo}

  @per_page 50

  def per_page, do: @per_page

  def states, do: Enum.map(Job.states(), &to_string/1)

  def state_counts(oban) do
    counts =
      oban
      |> Oban.config()
      |> Repo.all(from(j in Job, group_by: j.state, select: {j.state, count(j.id)}))
      |> Map.new()

    Enum.map(states(), &{&1, Map.get(counts, &1, 0)})
  end

  def queues(oban) do
    oban
    |> Oban.config()
    |> Repo.all(from(j in Job, distinct: true, select: j.queue, order_by: j.queue))
  end

  def list(oban, filters) do
    page = Map.get(filters, :page, 1)

    query =
      Job
      |> filter(:state, filters[:state])
      |> filter(:queue, filters[:queue])
      |> order_by(desc: :id)
      |> limit(^(@per_page + 1))
      |> offset(^((page - 1) * @per_page))

    jobs = Repo.all(Oban.config(oban), query)

    {Enum.take(jobs, @per_page), length(jobs) > @per_page}
  end

  def get(oban, id), do: Repo.get(Oban.config(oban), Job, id)

  defp filter(query, _field, nil), do: query
  defp filter(query, field, value), do: where(query, [j], field(j, ^field) == ^value)
end
