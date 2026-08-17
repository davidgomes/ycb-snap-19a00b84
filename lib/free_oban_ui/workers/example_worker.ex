defmodule FreeObanUi.Workers.ExampleWorker do
  @moduledoc false
  use Oban.Worker, queue: :default

  @impl Oban.Worker
  def perform(%Oban.Job{args: _args}) do
    :ok
  end
end
