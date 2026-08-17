defmodule FreeObanUi.Jobs do
  @moduledoc """
  Queries Oban jobs for the jobs UI.
  """

  import Ecto.Query

  alias FreeObanUi.Repo
  alias Oban.Job

  @states ~w(available scheduled executing retryable completed discarded cancelled)

  def states, do: @states

  def list_jobs(params \\ %{}) do
    Job
    |> filter_by_state(params)
    |> filter_by_queue(params)
    |> order_by([j], desc: j.id)
    |> limit(100)
    |> Repo.all()
  end

  def get_job!(id), do: Repo.get!(Job, id)

  def cancel_job(%Job{id: id}) do
    Oban.cancel_job(id)
  end

  def retry_job(%Job{id: id}) do
    Oban.retry_job(id)
  end

  defp filter_by_state(query, %{"state" => state}) when state in @states do
    where(query, [j], j.state == ^state)
  end

  defp filter_by_state(query, _), do: query

  defp filter_by_queue(query, %{"queue" => queue}) when is_binary(queue) and queue != "" do
    where(query, [j], j.queue == ^queue)
  end

  defp filter_by_queue(query, _), do: query
end
