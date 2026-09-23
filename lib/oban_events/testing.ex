defmodule ObanEvents.Testing do
  @moduledoc """
  Test helpers for ObanEvents handlers.

  Builds `ObanEvents.Event` structs so handlers can be unit tested without
  emitting events or constructing metadata by hand.

  ## Usage

      defmodule MyApp.EmailHandlerTest do
        use ExUnit.Case, async: true

        import ObanEvents.Testing

        test "sends welcome email" do
          event = build_event(%{user_id: 123, email: "test@example.com"})

          assert :ok = MyApp.EmailHandler.handle_event(:user_created, event)
        end
      end
  """

  alias ObanEvents.Event

  @doc """
  Builds an `ObanEvents.Event` for testing a handler.

  The data is JSON-encoded and decoded, the same way Oban stores job args, so
  the handler receives exactly what it would in production: string keys and
  JSON-compatible values.

  `event_id` and `idempotency_key` are generated unless given.
  `causation_id` and `correlation_id` default to `nil`.

  ## Options

  - `:event_id`
  - `:idempotency_key`
  - `:causation_id`
  - `:correlation_id`

  Raises `ArgumentError` for unknown options.

  ## Examples

      iex> event = build_event(%{user_id: 123})
      iex> event.data
      %{"user_id" => 123}

      iex> event = build_event(%{}, causation_id: "parent-event-id", correlation_id: "corr-123")
      iex> {event.causation_id, event.correlation_id}
      {"parent-event-id", "corr-123"}
  """
  @spec build_event(map(), keyword()) :: Event.t()
  def build_event(data, opts \\ []) when is_map(data) and is_list(opts) do
    opts = Keyword.validate!(opts, [:event_id, :idempotency_key, :causation_id, :correlation_id])

    %Event{
      data: data |> JSON.encode!() |> JSON.decode!(),
      event_id: Keyword.get_lazy(opts, :event_id, &UUIDv7.generate/0),
      idempotency_key: Keyword.get_lazy(opts, :idempotency_key, &UUIDv7.generate/0),
      causation_id: opts[:causation_id],
      correlation_id: opts[:correlation_id]
    }
  end
end
