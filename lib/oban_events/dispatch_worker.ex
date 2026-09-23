defmodule ObanEvents.DispatchWorker do
  @moduledoc """
  Generic Oban worker that dispatches events to their handlers.

  This worker:
  1. Receives an event name, handler module, and data from the job args
  2. Converts strings back to atoms safely
  3. Calls the handler's `handle_event/2` callback with an `ObanEvents.Event`
  4. Logs success/failure for observability

  ## Job Arguments

  - `event`: String representation of the event name
  - `handler`: String representation of the handler module
  - `data`: Map of event-specific data
  - `event_id`, `metadata`, `causation_id`, `correlation_id`, `emitted_at`: event metadata (optional)

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

  @impl Oban.Worker
  def perform(
        %Oban.Job{args: %{"event" => _, "handler" => handler_module_string, "data" => _} = args} =
          job
      ) do
    # These atoms should already exist since they were created during emit
    handler = String.to_existing_atom(handler_module_string)
    event_struct = ObanEvents.Event.from_args(args, job)
    event = event_struct.name

    Logger.info("Processing event: #{event} with handler: #{inspect(handler)}")

    case handler.handle_event(event, event_struct) do
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
