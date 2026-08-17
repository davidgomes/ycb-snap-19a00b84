defmodule ObanDoctor.Check.Worker.UniqueWithoutKeys do
  @moduledoc """
  Checks for workers with unique configuration but no explicit keys option.

  When using `unique: [fields: [:args]]` without specifying `keys`, Oban uses
  all fields from the job args for uniqueness. This can be problematic if:

  1. Args contain dynamic fields (timestamps, UUIDs) that should be ignored
  2. You want uniqueness based on only specific business identifiers

  ## Examples

  Potentially problematic:
      unique: [fields: [:args]]  # Uses ALL args fields

  Better - explicit about which args matter:
      unique: [fields: [:args], keys: [:user_id, :action]]
  """

  use ObanDoctor.Check, category: :worker

  @impl true
  def id, do: :unique_without_keys

  @impl true
  def description do
    "Detects workers with unique constraint but no explicit keys option"
  end

  @impl true
  def default_severity, do: :info

  @impl true
  def run(context) do
    workers = Map.get(context, :workers, [])

    workers
    |> Enum.filter(&has_unique_without_keys?/1)
    |> Enum.map(&build_issue/1)
  end

  defp has_unique_without_keys?(%{unique: unique}) when is_list(unique) do
    has_args_field? = :args in Keyword.get(unique, :fields, [])
    no_keys? = not Keyword.has_key?(unique, :keys)

    has_args_field? and no_keys?
  end

  defp has_unique_without_keys?(_), do: false

  defp build_issue(worker) do
    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Worker #{inspect(worker.module)} has unique constraint on :args without explicit keys",
      file: worker.file,
      line: worker.line,
      meta: %{
        worker: worker.module,
        unique_config: worker.unique
      }
    )
  end
end
