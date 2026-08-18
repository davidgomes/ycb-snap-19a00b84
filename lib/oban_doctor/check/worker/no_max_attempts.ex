defmodule ObanDoctor.Check.Worker.NoMaxAttempts do
  @moduledoc """
  Checks for workers that don't specify max_attempts.

  Oban's default max_attempts is 20, which is often too high for most workers.
  Jobs that fail 20 times can clog up your queue and waste resources on operations
  that are unlikely to succeed.

  Most workers should specify an explicit max_attempts based on:
  - Whether the operation is idempotent
  - Expected failure modes (network issues vs bugs)
  - Time sensitivity of the job

  ## Examples

  Using default (20 attempts):
      use Oban.Worker, queue: :default

  Explicit reasonable limit:
      use Oban.Worker, queue: :default, max_attempts: 3

  ## Documentation

  See [Oban.Worker Options](https://hexdocs.pm/oban/Oban.Worker.html#module-opts).
  """

  use ObanDoctor.Check, category: :worker

  @impl true
  def id, do: :no_max_attempts

  @impl true
  def description do
    "Detects workers using default max_attempts (20)"
  end

  @impl true
  def default_severity, do: :info

  @impl true
  def run(context) do
    workers = Map.get(context, :workers, [])

    workers
    |> Enum.filter(&no_max_attempts?/1)
    |> Enum.map(&build_issue/1)
  end

  defp no_max_attempts?(%{max_attempts: nil}), do: true
  defp no_max_attempts?(_), do: false

  defp build_issue(worker) do
    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message: "Worker #{inspect(worker.module)} uses default max_attempts (20)",
      file: worker.file,
      line: worker.line,
      meta: %{
        worker: worker.module
      }
    )
  end
end
