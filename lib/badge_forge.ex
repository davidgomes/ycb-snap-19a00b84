defmodule BadgeForge do
  @moduledoc """
  BadgeForge keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @doc """
  Enqueues a batch of badge generation jobs to the `:badges` queue for the Python worker.
  """
  def enqueue_batch(count \\ 100) do
    generate = fn _ ->
      args = %{
        id: Ecto.UUID.generate(),
        name: fake_name(),
        company: fake_company(),
        type: Enum.random(~w(attendee speaker sponsor organizer))
      }

      Oban.Job.new(args, worker: "badge_forge.generator.GenerateBadge", queue: :badges)
    end

    1..count
    |> Enum.map(generate)
    |> Oban.insert_all()
  end

  defp fake_name do
    first_names = ~w(Alasdair Ada Alan Grace Linus Margaret Dennis Barbara Tim Guido)
    last_names = ~w(Fraser Lovelace Turing Hopper Torvalds Hamilton Ritchie Liskov Berners-Lee van-Rossum)
    "#{Enum.random(first_names)} #{Enum.random(last_names)}"
  end

  defp fake_company do
    prefixes = ~w(Wavelength Apex Quantum Stellar Cyber Nexus Horizon Radiant)
    suffixes = ~w(Labs Technologies Systems Innovations Dynamics Software Solutions Media)
    "#{Enum.random(prefixes)} #{Enum.random(suffixes)}"
  end
end

