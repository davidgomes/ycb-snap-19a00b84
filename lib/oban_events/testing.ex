defmodule ObanEvents.Testing do
  @moduledoc """
  Test helpers for ObanEvents handlers.

  Builds `ObanEvents.Event` structs so handlers can be tested directly,
  without emitting events or constructing metadata by hand.

  ## Usage

      defmodule MyApp.EmailHandlerTest do
        use ExUnit.Case, async: true

        import ObanEvents.Testing

        test "sends welcome email" do
          event = build_event(%{"user_id" => 123, "email" => "test@example.com"})

          assert :ok = MyApp.EmailHandler.handle_event(:user_created, event)
        end
      end

  Handlers receive data with string keys in production, so use string keys
  in test data as well.
  """

  alias ObanEvents.Event

  @doc """
  Builds an `ObanEvents.Event` struct for testing.

  Generates `event_id` and `idempotency_key` unless given.
  `causation_id` and `correlation_id` default to `nil`.

  ## Options

  - `:event_id` - Override the generated event ID
  - `:idempotency_key` - Override the generated idempotency key
  - `:causation_id` - Set the causation ID
  - `:correlation_id` - Set the correlation ID

  Raises `ArgumentError` for unknown options.

  ## Examples

      iex> build_event(%{"user_id" => 123})
      %ObanEvents.Event{
        data: %{"user_id" => 123},
        event_id: "01933b7e-...",
        idempotency_key: "01933b7e-...",
        causation_id: nil,
        correlation_id: nil
      }

      iex> build_event(%{"user_id" => 123}, causation_id: "parent-event", correlation_id: "corr-123")
      %ObanEvents.Event{
        data: %{"user_id" => 123},
        event_id: "01933b7e-...",
        idempotency_key: "01933b7e-...",
        causation_id: "parent-event",
        correlation_id: "corr-123"
      }
  """
  @spec build_event(map(), keyword()) :: Event.t()
  def build_event(data, opts \\ []) when is_map(data) and is_list(opts) do
    opts =
      Keyword.validate!(opts, [:event_id, :idempotency_key, :causation_id, :correlation_id])

    %Event{
      data: data,
      event_id: Keyword.get_lazy(opts, :event_id, &Event.generate_id/0),
      idempotency_key: Keyword.get_lazy(opts, :idempotency_key, &Event.generate_id/0),
      causation_id: Keyword.get(opts, :causation_id),
      correlation_id: Keyword.get(opts, :correlation_id)
    }
  end
end
