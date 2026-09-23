defmodule FreeObanUi.Jobs do
  @moduledoc """
  Read and operate on Oban jobs for the jobs UI.
  """

  import Ecto.Query

  alias FreeObanUi.Repo

  @states ~w(available scheduled executing retryable completed discarded cancelled)

  def states, do: @states

  def list_jobs(filters \\ %{}) do
    Oban.Job
    |> filter_state(blank_to_nil(filters["state"]))
    |> filter_queue(blank_to_nil(filters["queue"]))
    |> order_by([j], desc: j.id)
    |> limit(50)
    |> Repo.all()
  end

  def get_job!(id), do: Repo.get!(Oban.Job, normalize_id(id))

  def cancel_job(id) do
    id = normalize_id(id)
    :ok = Oban.cancel_job(id)
    {:ok, get_job!(id)}
  end

  def retry_job(id) do
    id = normalize_id(id)
    :ok = Oban.retry_job(id)
    {:ok, get_job!(id)}
  end

  defp filter_state(query, nil), do: query
  defp filter_state(query, state), do: where(query, [j], j.state == ^state)

  defp filter_queue(query, nil), do: query

  defp filter_queue(query, queue) do
    where(query, [j], ilike(j.queue, ^"%#{queue}%"))
  end

  defp normalize_id(id) when is_integer(id), do: id
  defp normalize_id(id) when is_binary(id), do: String.to_integer(id)

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
