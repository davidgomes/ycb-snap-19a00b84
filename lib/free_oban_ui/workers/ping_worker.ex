defmodule FreeObanUi.Workers.PingWorker do
  @moduledoc """
  Sample worker used to enqueue jobs from the jobs UI.
  """
  use Oban.Worker

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"message" => message}}) when is_binary(message) do
    {:ok, message}
  end

  def perform(%Oban.Job{}) do
    :ok
  end
end
