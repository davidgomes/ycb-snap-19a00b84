defmodule BadgeForge do
  @moduledoc """
  BadgeForge keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @badge_types ~w(attendee attendee attendee attendee speaker speaker sponsor organizer)

  @doc """
  Enqueue a batch of badge generation jobs.

  Jobs are inserted into the shared `oban_jobs` table with worker
  `"badge_forge.workers.GenerateBadge"` on the `:badges` queue. A Python
  Oban process (see `python/badge_forge/workers.py`) picks them up.

  ## Examples

      iex> BadgeForge.enqueue_batch(100)
      :ok

  """
  def enqueue_batch(count \\ 100) do
    first_names = load_names("first_names.txt")
    last_names = load_names("last_names.txt")
    companies = load_names("companies.txt")

    generate = fn _ ->
      args = %{
        id: Ecto.UUID.generate(),
        name: "#{Enum.random(first_names)} #{Enum.random(last_names)}",
        company: Enum.random(companies),
        type: Enum.random(@badge_types)
      }

      Oban.Job.new(args, worker: "badge_forge.workers.GenerateBadge", queue: :badges)
    end

    1..count
    |> Enum.map(generate)
    |> Oban.insert_all()

    :ok
  end

  defp load_names(filename) do
    :badge_forge
    |> :code.priv_dir()
    |> Path.join("names/#{filename}")
    |> File.read!()
    |> String.split("\n", trim: true)
  end
end
