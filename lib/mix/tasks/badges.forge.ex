defmodule Mix.Tasks.Badges.Forge do
  @shortdoc "Enqueues sample badge generation jobs for the Python Oban worker"

  @moduledoc """
  Enqueues a batch of badge generation jobs, handing them off to the Python
  Oban worker (see `python/badge_forge/generator.py`).

      $ mix badges.forge
      $ mix badges.forge --count 25

  See `BadgeForge.Badges.enqueue_batch/1`.
  """

  use Mix.Task

  alias BadgeForge.Badges

  @names ~w(Ada Grace Alan Katherine Linus Barbara Dennis Radia)
  @companies ~w(Soren Acme Globex Initech Umbrella Hooli)
  @types ~w(attendee speaker sponsor organizer)

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: [count: :integer])
    count = Keyword.get(opts, :count, 10)

    Mix.Task.run("app.start")

    jobs =
      1..count
      |> Enum.map(fn _ -> sample_attrs() end)
      |> Badges.enqueue_batch()

    Mix.shell().info("Enqueued #{length(jobs)} badge job(s) for the Python worker.")
  end

  defp sample_attrs do
    %{
      name: Enum.random(@names),
      company: Enum.random(@companies),
      type: Enum.random(@types)
    }
  end
end
