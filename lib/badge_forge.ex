defmodule BadgeForge do
  @moduledoc """
  BadgeForge keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @python_worker "badge_forge.generator.GenerateBadge"
  @badge_types ~w(attendee attendee attendee attendee speaker speaker sponsor organizer)
  @first_names ~w(Ada Amara Grace James Kai Maya Priya Quinn Theo Yuki)
  @last_names ~w(Abbott Brooks Campbell Garcia Hansen Patel Singh Torres Wallace Williams)
  @companies [
    "Beacon Labs",
    "CloudNine Systems",
    "Gradient AI",
    "Lighthouse Data",
    "Wavelength Tech"
  ]

  @doc """
  Enqueues fake conference badges for the Python Oban worker.

  The jobs use the Python worker's fully qualified name and are inserted into
  the shared `oban_jobs` table. The Elixir Oban instance doesn't run the
  `badges` queue; a Python Oban process connected to the same database does.

  ## Examples

      iex> BadgeForge.enqueue_batch(10)
      :ok

  """
  def enqueue_batch(count \\ 100)

  def enqueue_batch(0), do: :ok

  def enqueue_batch(count) when is_integer(count) and count > 0 do
    1..count
    |> Enum.map(fn _ -> new_badge_job() end)
    |> Oban.insert_all()

    :ok
  end

  defp new_badge_job do
    args = %{
      "id" => Ecto.UUID.generate(),
      "name" => "#{Enum.random(@first_names)} #{Enum.random(@last_names)}",
      "company" => Enum.random(@companies),
      "type" => Enum.random(@badge_types)
    }

    Oban.Job.new(args, worker: @python_worker, queue: :badges)
  end
end
