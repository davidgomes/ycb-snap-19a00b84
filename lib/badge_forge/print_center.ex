defmodule BadgeForge.PrintCenter do
  use Oban.Worker, queue: :printing

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id, "name" => name, "path" => path}}) do
    Logger.info("Printing badge #{id} for #{name}: #{path}...")
    :ok
  end
end
