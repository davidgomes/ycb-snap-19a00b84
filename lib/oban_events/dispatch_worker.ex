defmodule ObanEvents.DispatchWorker do
  @moduledoc """
  Generic Oban worker that dispatches events to their handlers.

  This worker:
  1. Receives an event name, handler module, data, and metadata from the job args
  2. Converts strings back to atoms safely
  3. Rebuilds the `ObanEvents.Event` and calls the handler's `handle_event/2` callback
  4. Logs success/failure for observability

  ## Job Arguments

  - `event`: String representation of the event name
  - `handler`: String representation of the handler module
  - `data`: Map of event-specific data
  - `event_id`: Unique identifier of the emission (shared by all handlers)
  - `emitted_at`: ISO8601 timestamp of the emission
  - `causation_id`: `event_id` of the causing event, or `nil`
  - `correlation_id`: Correlation identifier of the event chain
  - `metadata`: Map of additional metadata

  Jobs missing the metadata keys (e.g., enqueued by older versions) are
  still processed; the corresponding `ObanEvents.Event` fields are `nil`
  (or `%{}` for `metadata`).

  ## Configuration

  Queue, max_attempts, and priority are configured per event bus module
  when using `ObanEvents`. Jobs are created with these settings via
  `new/2` options.

  ## Observability

  All event processing is logged at INFO level for successful processing
  and ERROR level for failures. Check Oban Web UI for job history.
  """

  use Oban.Worker

  alias ObanEvents.Event

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{
        args:
          %{"event" => event_name_string, "handler" => handler_module_string, "data" => _} = args
      }) do
    # Safely convert strings back to atoms
    # These atoms should already exist since they were created during emit
    event = String.to_existing_atom(event_name_string)
    handler = String.to_existing_atom(handler_module_string)

    Logger.info("Processing event: #{event} with handler: #{inspect(handler)}")

    case handler.handle_event(event, Event.from_job_args(event, args)) do
      :ok ->
        Logger.info("Event processed successfully: #{event} by #{inspect(handler)}")
        :ok

      {:ok, result} ->
        Logger.info(
          "Event processed successfully: #{event} by #{inspect(handler)}, result: #{inspect(result)}"
        )

        :ok

      {:error, reason} = error ->
        Logger.error(
          "Event handler failed: #{event} by #{inspect(handler)}, error: #{inspect(reason)}"
        )

        # Return error to trigger Oban retry
        error

      other ->
        Logger.warning(
          "Event handler returned unexpected value: #{inspect(other)} for #{event} by #{inspect(handler)}"
        )

        # Treat unexpected returns as success to avoid retry loops
        :ok
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: args} = job) do
    Logger.error(
      "DispatchWorker received invalid job arguments: job_id=#{job.id}, args=#{inspect(args)}"
    )

    {:error, "Invalid job arguments: missing event, handler, or data"}
  end
end
