defmodule BadgeForge.PrintCenter do
  @moduledoc """
  Handles badges that the Python generator finished rendering.

  Python enqueues these jobs directly, there's no Elixir code involved in the
  insert. Only the worker name and queue have to line up.
  """

  use Oban.Worker, queue: :printing, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"name" => name, "path" => path}}) do
    Logger.info("printing badge for #{name} from #{path}")

    :ok
  end
end
