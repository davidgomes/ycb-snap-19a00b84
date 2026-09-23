defmodule ObanEvents.Testing do
  @moduledoc """
  Helpers for testing event handlers.

      import ObanEvents.Testing

      test "sends welcome email" do
        assert :ok = call_handler(MyApp.EmailHandler, :user_created, %{user_id: 1})
      end
  """

  alias ObanEvents.Event

  @doc """
  Builds an `ObanEvents.Event` as a handler would receive it.

  Data and metadata keys are stringified, mirroring JSON serialization.

  ## Options

  - `:metadata` - metadata map (default: `%{}`)
  - `:event_id` - event id (default: random UUID)
  - `:emitted_at` - emission time (default: `DateTime.utc_now/0`)
  - `:job_id`, `:attempt` - Oban job fields (default: `nil`, `1`)
  """
  @spec build_event(atom(), map(), keyword()) :: Event.t()
  def build_event(name, data \\ %{}, opts \\ []) when is_atom(name) and is_map(data) do
    %Event{
      name: name,
      data: stringify(data),
      event_id: Keyword.get_lazy(opts, :event_id, &Event.generate_id/0),
      emitted_at: Keyword.get_lazy(opts, :emitted_at, &DateTime.utc_now/0),
      metadata: stringify(Keyword.get(opts, :metadata, %{})),
      job_id: Keyword.get(opts, :job_id),
      attempt: Keyword.get(opts, :attempt, 1)
    }
  end

  @doc """
  Builds an event with `build_event/3` and invokes `handler.handle_event/2` directly.
  """
  @spec call_handler(module(), atom(), map(), keyword()) :: term()
  def call_handler(handler, name, data \\ %{}, opts \\ []) do
    handler.handle_event(name, build_event(name, data, opts))
  end

  defp stringify(map), do: map |> Jason.encode!() |> Jason.decode!()
end
