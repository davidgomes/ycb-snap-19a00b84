defmodule ObanEvents.Testing do
  @moduledoc """
  Test helpers for ObanEvents handlers.

  Builds `ObanEvents.Event` structs so handlers can be unit tested directly,
  without constructing every metadata field by hand.

  ## Usage

      defmodule MyApp.EmailHandlerTest do
        use ExUnit.Case
        import ObanEvents.Testing

        test "sends welcome email" do
          event = build_event(%{"user_id" => 123, "email" => "test@example.com"})

          assert :ok = MyApp.EmailHandler.handle_event(:user_created, event)
        end
      end
  """

  alias ObanEvents.Event

  @doc """
  Builds an `ObanEvents.Event` struct for testing.

  Generates `event_id` and `idempotency_key` unless provided. `causation_id`
  and `correlation_id` default to `nil`.

  Data keys are converted to strings, matching what handlers receive at runtime.

  ## Options

  - `:event_id`
  - `:idempotency_key`
  - `:causation_id`
  - `:correlation_id`

  ## Examples

      build_event(%{"user_id" => 123})

      build_event(%{user_id: 123},
        causation_id: "parent-event-id",
        correlation_id: "correlation-id"
      )
  """
  @spec build_event(map(), keyword()) :: Event.t()
  def build_event(data \\ %{}, opts \\ []) when is_map(data) and is_list(opts) do
    opts =
      Keyword.validate!(opts, [:event_id, :idempotency_key, :causation_id, :correlation_id])

    %Event{
      data: stringify_keys(data),
      event_id: Keyword.get_lazy(opts, :event_id, &Ecto.UUID.generate/0),
      idempotency_key: Keyword.get_lazy(opts, :idempotency_key, &Ecto.UUID.generate/0),
      causation_id: Keyword.get(opts, :causation_id),
      correlation_id: Keyword.get(opts, :correlation_id)
    }
  end

  defp stringify_keys(%_{} = struct), do: struct

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), stringify_keys(value)} end)
  end

  defp stringify_keys(list) when is_list(list), do: Enum.map(list, &stringify_keys/1)
  defp stringify_keys(value), do: value
end
