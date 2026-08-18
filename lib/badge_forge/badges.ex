defmodule BadgeForge.Badges do
  @moduledoc """
  Enqueue badge generation jobs for the Python workers.

  Jobs are inserted into the shared `oban_jobs` table with the fully qualified
  name of a Python worker. Nothing else is needed for the handoff: the Python
  process listening on the `badges` queue picks the job up, generates the badge,
  and enqueues a `BadgeForge.PrintCenter` job back to Elixir.
  """

  @generator "badge_forge.generator.GenerateBadge"
  @queue :badges

  @doc """
  Build a job for the Python generator without inserting it.
  """
  def new_badge(attrs) do
    attrs
    |> normalize()
    |> Oban.Job.new(worker: @generator, queue: @queue, max_attempts: 5)
  end

  @doc """
  Insert a single badge generation job.
  """
  def enqueue_badge(attrs) do
    attrs
    |> new_badge()
    |> Oban.insert()
  end

  @doc """
  Insert badge generation jobs for a list of attendees in a single statement.
  """
  def enqueue_badges(attendees) do
    attendees
    |> Enum.map(&new_badge/1)
    |> Oban.insert_all()
  end

  defp normalize(attrs) do
    attrs
    |> Map.new(fn {key, value} -> {to_string(key), value} end)
    |> Map.put_new_lazy("id", &Ecto.UUID.generate/0)
  end
end
