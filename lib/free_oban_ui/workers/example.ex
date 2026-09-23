defmodule FreeObanUi.Workers.Example do
  @moduledoc false
  use Oban.Worker, queue: :default

  @impl Oban.Worker
  def perform(%Oban.Job{}), do: :ok
end
