defmodule BadgeForge.PrintCenter do
  use Oban.Worker, queue: :printing

  require Logger

  @impl true
  def perform(%Oban.Job{args: %{"name" => name, "path" => path}}) do
    Logger.info("Printing badge for #{name}: #{path}")

    :ok
  end
end
