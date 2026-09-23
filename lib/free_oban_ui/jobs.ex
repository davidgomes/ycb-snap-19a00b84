defmodule FreeObanUi.Jobs do
  @moduledoc """
  Read and operate on Oban jobs stored in the database.
  """

  import Ecto.Query

  alias FreeObanUi.Repo

  @states ~w(available scheduled executing retryable completed discarded cancelled)

  def states, do: @states

  def list_jobs(opts \\ []) do
    state = opts[:state]

    Oban.Job
    |> maybe_filter_state(state)
    |> order_by([j], desc: j.id)
    |> limit(100)
    |> Repo.all()
  end

  def get_job!(id) do
    Repo.get!(Oban.Job, id)
  end

  def retry_job(%Oban.Job{id: id}), do: Oban.retry_job(id)

  def cancel_job(%Oban.Job{id: id}), do: Oban.cancel_job(id)

  defp maybe_filter_state(query, state) when state in @states do
    where(query, [j], j.state == ^state)
  end

  defp maybe_filter_state(query, _), do: query
end
