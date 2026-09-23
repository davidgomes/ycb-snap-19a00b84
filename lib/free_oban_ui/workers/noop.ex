defmodule FreeObanUi.Workers.Noop do
  @moduledoc false
  use Oban.Worker, queue: :default

  @impl Oban.Worker
  def perform(_job), do: :ok
end
