defmodule ObanEvents.DispatchWorker do
  @moduledoc """
  Generic Oban worker that dispatches events to their handlers.

  This worker:
  1. Receives an event name, handler module, data, and metadata from the job args
  2. Converts strings back to atoms safely
  3. Calls the handler's callback: `handle_event/3` (if exported) or `handle_event/2`
  4. Logs success/failure for observability

  ## Job Arguments

  - `event`: String representation of the event name
  - `handler`: String representation of the handler module
  - `data`: Map of event-specific data
  - `id`: Optional unique event identifier string
  - `timestamp`: Optional ISO8601 timestamp string
  - `correlation_id`: Optional correlation ID string
  - `causation_id`: Optional causation ID string
  - `metadata`: Map of additional event metadata

  ## Configuration

  Queue, max_attempts, and priority are configured per event bus module
  when using `ObanEvents`. Jobs are created with these settings via
  `new/2` options.

  ## Observability

  All event processing is logged at INFO level for successful processing
  and ERROR level for failures. Check Oban Web UI for job history.
  """

  use Oban.Worker

  require Logger

  alias ObanEvents.Event

  @impl Oban.Worker
  def perform(%Oban.Job{
        args:
          %{"event" => event_name_string, "handler" => handler_module_string, "data" => data} =
            args
      }) do
    # Safely convert strings back to atoms
    # These atoms should already exist since they were created during emit
    event = String.to_existing_atom(event_name_string)
    handler = String.to_existing_atom(handler_module_string)

    Logger.info("Processing event: #{event} with handler: #{inspect(handler)}")

    event_struct = Event.from_map(args)

    result =
      if function_exported?(handler, :handle_event, 3) do
        handler.handle_event(event, data, event_struct)
      else
        handler.handle_event(event, data)
      end

    case result do
      :ok ->
        Logger.info("Event processed successfully: #{event} by #{inspect(handler)}")
        :ok

      {:ok, res} ->
        Logger.info(
          "Event processed successfully: #{event} by #{inspect(handler)}, result: #{inspect(res)}"
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
