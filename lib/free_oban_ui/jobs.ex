defmodule FreeObanUi.Jobs do
  @moduledoc """
  Queries used by the jobs dashboard.
  """

  import Ecto.Query

  alias FreeObanUi.Repo
  alias Oban.Job

  @states ~w(available scheduled executing retryable completed discarded cancelled)
  @page_size 50

  def states, do: @states

  def list(params \\ %{}) do
    state = valid_state(params["state"])
    queue = present(params["queue"])

    jobs =
      Job
      |> maybe_filter(:state, state)
      |> maybe_filter(:queue, queue)
      |> order_by([job], desc: job.inserted_at)
      |> limit(@page_size)
      |> Repo.all()

    %{jobs: jobs, state: state, queue: queue}
  end

  def counts do
    Job
    |> group_by([job], job.state)
    |> select([job], {job.state, count(job.id)})
    |> Repo.all()
    |> Map.new()
  end

  def queues do
    Job
    |> distinct(true)
    |> order_by([job], asc: job.queue)
    |> select([job], job.queue)
    |> Repo.all()
  end

  defp maybe_filter(query, _field, nil), do: query
  defp maybe_filter(query, field, value), do: where(query, [job], field(job, ^field) == ^value)

  defp valid_state(state) when state in @states, do: state
  defp valid_state(_state), do: nil

  defp present(value) when is_binary(value) and value != "", do: value
  defp present(_value), do: nil
end
