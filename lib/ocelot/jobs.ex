defmodule Ocelot.Jobs do
  @moduledoc false

  import Ecto.Query

  alias Oban.{Job, Repo}

  @states ~w(available scheduled executing retryable completed discarded cancelled)
  @default_limit 100

  def states, do: @states

  def default_limit, do: @default_limit

  def normalize_state(state) when state in @states, do: state
  def normalize_state(_state), do: nil

  def state_counts(oban) do
    counts =
      oban
      |> Oban.config()
      |> Repo.all(from(j in Job, group_by: j.state, select: {j.state, count(j.id)}))
      |> Map.new()

    Map.new(@states, &{&1, Map.get(counts, &1, 0)})
  end

  def list(oban, opts) do
    query =
      Job
      |> order_by(desc: :id)
      |> limit(^Keyword.fetch!(opts, :limit))

    query =
      case Keyword.get(opts, :state) do
        nil -> query
        state -> where(query, [j], j.state == ^state)
      end

    oban
    |> Oban.config()
    |> Repo.all(query)
  end

  def get(oban, id) do
    oban
    |> Oban.config()
    |> Repo.get(Job, id)
  end

  def perform_action(oban, "retry", id), do: Oban.retry_job(oban, id)
  def perform_action(oban, "cancel", id), do: Oban.cancel_job(oban, id)
  def perform_action(oban, "delete", id), do: Oban.delete_job(oban, id)
end
