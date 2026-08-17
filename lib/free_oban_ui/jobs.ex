defmodule FreeObanUi.Jobs do
  @moduledoc """
  Read and control Oban jobs for the jobs UI.
  """

  import Ecto.Query

  alias FreeObanUi.Repo
  alias Oban.Job

  @states ~w(available scheduled executing retryable completed cancelled discarded)

  def states, do: @states

  def list_jobs(params \\ %{}) do
    Job
    |> maybe_filter_state(params)
    |> maybe_filter_queue(params)
    |> order_by([j], desc: j.id)
    |> limit(100)
    |> Repo.all()
  end

  def get_job!(id) when is_binary(id), do: get_job!(String.to_integer(id))
  def get_job!(id), do: Repo.get!(Job, id)

  def retry_job(id) do
    id
    |> get_job!()
    |> Oban.retry_job()
    |> normalize_oban_result()
  end

  def cancel_job(id) do
    id
    |> get_job!()
    |> Oban.cancel_job()
    |> normalize_oban_result()
  end

  defp normalize_oban_result(:ok), do: :ok
  defp normalize_oban_result({:ok, _job}), do: :ok
  defp normalize_oban_result(other), do: other

  defp maybe_filter_state(query, %{"state" => state}) when state in @states do
    where(query, [j], j.state == ^state)
  end

  defp maybe_filter_state(query, _), do: query

  defp maybe_filter_queue(query, %{"queue" => queue}) when is_binary(queue) and queue != "" do
    where(query, [j], j.queue == ^queue)
  end

  defp maybe_filter_queue(query, _), do: query
end
