defmodule ObanEvents.DispatchWorker do
  @moduledoc """
  Generic Oban worker that dispatches events to their handlers.

  This worker:
  1. Rebuilds an `ObanEvents.Event` struct from the job args
  2. Calls the handler's `handle_event/3` callback, falling back to `handle_event/2`
  3. Logs success/failure for observability

  ## Job Arguments

  - `event`: String representation of the event name
  - `handler`: String representation of the handler module
  - `data`: Map of event-specific data
  - `meta`: Map of metadata supplied by the emitter
  - `event_id`: Unique id shared by every handler job of the same emit call
  - `emitted_at`: ISO8601 timestamp of when the event was emitted

  Jobs enqueued before metadata was introduced only carry `event`, `handler` and
  `data`, and are still dispatched.

  ## Configuration

  Queue, max_attempts, and priority are configured per event bus module
  when using `ObanEvents`. Jobs are created with these settings via
  `new/2` options.

  ## Observability

  All event processing is logged at INFO level for successful processing
  and ERROR level for failures. Log lines include the event id and Oban job id
  so a single emit can be traced across its handlers. Check Oban Web UI for job
  history.
  """

  use Oban.Worker

  require Logger

  alias ObanEvents.Event

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"event" => _, "handler" => _, "data" => _}} = job) do
    {:ok, event} = Event.from_job(job)

    Logger.info(
      "Processing event: #{event.name} with handler: #{inspect(event.handler)}#{context(event)}"
    )

    event
    |> dispatch()
    |> handle_result(event)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: args} = job) do
    Logger.error(
      "DispatchWorker received invalid job arguments: job_id=#{job.id}, args=#{inspect(args)}"
    )

    {:error, "Invalid job arguments: missing event, handler, or data"}
  end

  defp dispatch(%Event{handler: handler} = event) do
    if metadata_aware?(handler) do
      handler.handle_event(event.name, event.data, event)
    else
      handler.handle_event(event.name, event.data)
    end
  end

  defp metadata_aware?(handler) do
    Code.ensure_loaded?(handler) and function_exported?(handler, :handle_event, 3)
  end

  defp handle_result(:ok, event) do
    Logger.info(
      "Event processed successfully: #{event.name} by #{inspect(event.handler)}#{context(event)}"
    )

    :ok
  end

  defp handle_result({:ok, result}, event) do
    Logger.info(
      "Event processed successfully: #{event.name} by #{inspect(event.handler)}, result: #{inspect(result)}#{context(event)}"
    )

    :ok
  end

  defp handle_result({:error, reason} = error, event) do
    Logger.error(
      "Event handler failed: #{event.name} by #{inspect(event.handler)}, error: #{inspect(reason)}#{context(event)}"
    )

    # Return error to trigger Oban retry
    error
  end

  defp handle_result(other, event) do
    Logger.warning(
      "Event handler returned unexpected value: #{inspect(other)} for #{event.name} by #{inspect(event.handler)}#{context(event)}"
    )

    # Treat unexpected returns as success to avoid retry loops
    :ok
  end

  defp context(%Event{} = event) do
    details =
      [event_id: event.id, job_id: event.job_id, attempt: event.attempt]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.map_join(", ", fn {key, value} -> "#{key}=#{value}" end)

    if details == "", do: "", else: " (#{details})"
  end
end
