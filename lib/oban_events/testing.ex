defmodule ObanEvents.Testing do
  @moduledoc """
  Test helpers for ObanEvents handlers.

  Handlers can be unit tested by calling `handle_event/2` directly with an
  event built by `build_event/2`, without having to construct every metadata
  field by hand:

      defmodule MyApp.EmailHandlerTest do
        use ExUnit.Case, async: true

        import ObanEvents.Testing

        test "sends a welcome email" do
          event = build_event(%{user_id: 123, email: "test@example.com"})

          assert :ok = MyApp.EmailHandler.handle_event(:user_created, event)
        end
      end
  """

  alias ObanEvents.Event

  @doc """
  Builds an `ObanEvents.Event` for testing a handler.

  The data is round-tripped through JSON, like it is when an emitted event is
  persisted, so the handler receives the same shape it gets in production
  (e.g. atom keys become string keys).

  `event_id` and `idempotency_key` are generated unless given.
  `causation_id` and `correlation_id` default to `nil`.

  ## Options

  - `:event_id` - Override the generated event ID
  - `:idempotency_key` - Override the generated idempotency key
  - `:causation_id` - Set the causation ID
  - `:correlation_id` - Set the correlation ID

  ## Examples

      iex> event = build_event(%{user_id: 123}, causation_id: "parent-event-id")
      iex> event.data
      %{"user_id" => 123}
      iex> event.causation_id
      "parent-event-id"

  Raises `ArgumentError` if an unknown option is given.
  """
  @spec build_event(map(), keyword()) :: Event.t()
  def build_event(data, opts \\ []) when is_map(data) do
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
