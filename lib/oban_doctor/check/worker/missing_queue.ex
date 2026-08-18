defmodule ObanDoctor.Check.Worker.MissingQueue do
  @moduledoc """
  Checks for workers using queues that are not defined in the Oban configuration.

  Workers should only use queues that are configured in the application's Oban setup.
  Using an undefined queue means the job will never be processed.

  ## Documentation

  See [Oban Queues Configuration](https://hexdocs.pm/oban/Oban.html#module-queues).
  """

  use ObanDoctor.Check, category: :worker

  @impl true
  def id, do: :missing_queue

  @impl true
  def description do
    "Detects workers using queues not defined in Oban configuration"
  end

  @impl true
  def default_severity, do: :error

  @impl true
  def run(context) do
    workers = Map.get(context, :workers, [])
    defined_queues = Map.get(context, :defined_queues, MapSet.new())

    workers
    |> Enum.filter(&has_undefined_queue?(&1, defined_queues))
    |> Enum.map(&build_issue/1)
  end

  defp has_undefined_queue?(%{queue: nil}, _defined_queues), do: false

  defp has_undefined_queue?(%{queue: queue}, defined_queues) when is_atom(queue) do
    not MapSet.member?(defined_queues, queue)
  end

  defp has_undefined_queue?(_, _), do: false

  defp build_issue(worker) do
    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message: "Worker #{inspect(worker.module)} uses undefined queue :#{worker.queue}",
      file: worker.file,
      line: worker.line,
      meta: %{
        worker: worker.module,
        queue: worker.queue
      }
    )
  end
end
