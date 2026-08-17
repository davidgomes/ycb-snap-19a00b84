defmodule BadgeForge.Badges do
  @moduledoc """
  Enqueues conference badge generation jobs.

  Badges are rendered by a Python Oban worker (`badge_forge.generator.GenerateBadge`,
  see `python/badge_forge/generator.py`). Oban for Elixir and Oban for Python read and
  write the same `oban_jobs` table, so enqueueing a job here is all that's needed to
  hand the work off — the Python worker polls the `badges` queue and processes it there.
  """

  @worker "badge_forge.generator.GenerateBadge"
  @queue :badges

  @type attrs :: %{
          optional(:id) => String.t(),
          name: String.t(),
          company: String.t(),
          type: String.t()
        }

  @doc """
  Enqueues a single badge generation job for the Python worker.

  An `:id` is generated automatically when one isn't supplied.
  """
  @spec enqueue(attrs()) :: {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def enqueue(attrs) do
    attrs
    |> job_changeset()
    |> Oban.insert()
  end

  @doc """
  Enqueues a batch of badge generation jobs for the Python worker in a single
  database round-trip.
  """
  @spec enqueue_batch([attrs()]) :: [Oban.Job.t()]
  def enqueue_batch(attrs_list) when is_list(attrs_list) do
    attrs_list
    |> Enum.map(&job_changeset/1)
    |> Oban.insert_all()
  end

  defp job_changeset(attrs) do
    args =
      attrs
      |> Map.new()
      |> Map.put_new_lazy(:id, fn -> Ecto.UUID.generate() end)

    Oban.Job.new(args, worker: @worker, queue: @queue)
  end
end
