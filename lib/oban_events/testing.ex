defmodule ObanEvents.Testing do
  @moduledoc """
  Helpers for testing event handlers.

  ## Usage

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
  Builds an `ObanEvents.Event` for calling a handler directly in tests.

  `data` is round-tripped through JSON, the same way Oban serializes job args,
  so handlers receive string keys just like in production. `event_id` and
  `idempotency_key` are generated unless given.

  ## Options

  - `:event_id` - Defaults to a generated UUID
  - `:idempotency_key` - Defaults to a generated UUID
  - `:causation_id` - Defaults to `nil`
  - `:correlation_id` - Defaults to `nil`

  Raises `ArgumentError` if an unknown option is given.

  ## Examples

      build_event(%{user_id: 123})
      #=> %ObanEvents.Event{data: %{"user_id" => 123}, event_id: "...", idempotency_key: "...", ...}

      build_event(%{"user_id" => 123},
        causation_id: parent_event.event_id,
        correlation_id: parent_event.correlation_id
      )
  """
  @spec build_event(map(), keyword()) :: Event.t()
  def build_event(data, opts \\ []) when is_map(data) and is_list(opts) do
    opts = Keyword.validate!(opts, [:event_id, :idempotency_key, :causation_id, :correlation_id])

    %Event{
      data: data |> JSON.encode!() |> JSON.decode!(),
      event_id: Keyword.get_lazy(opts, :event_id, &Ecto.UUID.generate/0),
      idempotency_key: Keyword.get_lazy(opts, :idempotency_key, &Ecto.UUID.generate/0),
      causation_id: opts[:causation_id],
      correlation_id: opts[:correlation_id]
    }
  end
end
