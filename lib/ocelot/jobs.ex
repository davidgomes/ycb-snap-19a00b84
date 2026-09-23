defmodule Ocelot.Jobs do
  @moduledoc false

  import Ecto.Query

  alias Oban.{Job, Repo}

  @states ~w(available scheduled executing retryable completed discarded cancelled)

  def states, do: @states

  def state_counts(oban) do
    counts =
      Job
      |> group_by([j], j.state)
      |> select([j], {j.state, count(j.id)})
      |> then(&Repo.all(Oban.config(oban), &1))
      |> Map.new()

    Enum.map(@states, &{&1, Map.get(counts, &1, 0)})
  end

  def queue_counts(oban) do
    Job
    |> group_by([j], [j.queue, j.state])
    |> select([j], {j.queue, j.state, count(j.id)})
    |> then(&Repo.all(Oban.config(oban), &1))
    |> Enum.group_by(&elem(&1, 0), fn {_queue, state, count} -> {state, count} end)
    |> Enum.map(fn {queue, counts} -> {queue, Map.new(counts)} end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  def list_jobs(oban, state, limit) when state in @states do
    Job
    |> where([j], j.state == ^state)
    |> order_by([j], desc: j.id)
    |> limit(^limit)
    |> then(&Repo.all(Oban.config(oban), &1))
  end

  def get_job(oban, id) do
    Repo.get(Oban.config(oban), Job, id)
  end
end
