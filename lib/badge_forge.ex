defmodule BadgeForge do
  @moduledoc """
  BadgeForge keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @doc """
  Enqueue a job to generate a badge PDF for an attendee.

  The job is inserted into the shared `oban_jobs` table and picked up
  and processed by the Python worker defined in
  `python/badge_forge/workers.py`, not by this Elixir application.

  ## Examples

      iex> BadgeForge.generate_badge("attendee-123", "Ada Lovelace")
      {:ok, %Oban.Job{}}

  """
  def generate_badge(attendee_id, name) do
    %{attendee_id: attendee_id, name: name}
    |> Oban.Job.new(worker: "badge_forge.workers.GenerateBadge", queue: :badges)
    |> Oban.insert()
  end
end
