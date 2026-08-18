defmodule Ocelot.Jobs do
  @moduledoc """
  Read only access to the Oban jobs table.
  """

  import Ecto.Query

  @states ~w(available scheduled executing retryable completed discarded cancelled)

  @default_limit 50

  def states, do: @states

  @doc """
  Lists jobs, most recently inserted first.

  Supported options:

    * `:state` - only return jobs in the given state
    * `:limit` - maximum number of jobs to return, defaults to #{@default_limit}
  """
  def list(oban_name \\ Oban, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)

    Oban.Job
    |> filter_state(Keyword.get(opts, :state))
    |> order_by(desc: :id)
    |> limit(^limit)
    |> repo(oban_name).all()
  end

  @doc """
  Returns the job count for every state, including states without any job.
  """
  def counts(oban_name \\ Oban) do
    counted =
      Oban.Job
      |> group_by([j], j.state)
      |> select([j], {j.state, count(j.id)})
      |> repo(oban_name).all()
      |> Map.new()

    Map.new(@states, fn state -> {state, Map.get(counted, state, 0)} end)
  end

  defp filter_state(query, state) when state in @states, do: where(query, state: ^state)
  defp filter_state(query, _state), do: query

  defp repo(oban_name), do: Oban.config(oban_name).repo
end
