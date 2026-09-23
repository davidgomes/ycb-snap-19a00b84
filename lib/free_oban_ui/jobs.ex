defmodule FreeObanUi.Jobs do
  @moduledoc """
  Queries for inspecting Oban jobs.
  """

  import Ecto.Query

  alias FreeObanUi.Repo

  @states ~w(available scheduled executing retryable completed discarded cancelled)

  def states, do: @states

  def list_jobs(opts \\ []) do
    state = Keyword.get(opts, :state)
    limit = Keyword.get(opts, :limit, 50)

    Oban.Job
    |> filter_state(state)
    |> order_by(desc: :id)
    |> limit(^limit)
    |> Repo.all()
  end

  def count_by_state do
    counts =
      Oban.Job
      |> group_by([j], j.state)
      |> select([j], {j.state, count(j.id)})
      |> Repo.all()
      |> Map.new()

    Map.new(@states, &{&1, Map.get(counts, &1, 0)})
  end

  defp filter_state(query, state) when state in @states, do: where(query, [j], j.state == ^state)
  defp filter_state(query, _), do: query
end
