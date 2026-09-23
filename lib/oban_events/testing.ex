defmodule ObanEvents.Testing do
  @moduledoc """
  Helpers for testing event handlers and emitted events.

  Handlers receive events after a round trip through the Oban job args, so event data and
  metadata arrive with string keys and JSON-encoded values. These helpers build events the
  same way, so handler tests exercise what handlers see in production.

  ## Testing Handlers

      import ObanEvents.Testing

      test "sends welcome email" do
        assert :ok =
                 perform_event(MyApp.EmailHandler, :user_created, %{user_id: 1, email: "a@b.c"},
                   metadata: %{actor_id: 2}
                 )
      end

      test "handler with a hand-built event" do
        event = build_event(:user_created, %{user_id: 1})
        assert %{"user_id" => 1} = event.data
        assert :ok = MyApp.EmailHandler.handle_event(:user_created, event)
      end

  ## Inspecting Emitted Events

  `to_event/1` turns a `DispatchWorker` job, such as those returned by `emit/3` or
  `Oban.Testing.all_enqueued/1`, back into an `ObanEvents.Event`:

      {:ok, [job]} = MyApp.Events.emit(:user_created, %{user_id: 1}, metadata: %{actor_id: 2})

      assert %ObanEvents.Event{name: :user_created, metadata: %{"actor_id" => 2}} = to_event(job)
  """

  alias ObanEvents.Event

  @doc """
  Build an `ObanEvents.Event` as a handler would receive it.

  Data and metadata are JSON round-tripped, so keys become strings and values are
  JSON-encoded (e.g., atoms become strings).

  Accepts all options of `ObanEvents.Event.new/3`, including `:id` and `:emitted_at`
  for deterministic tests.
  """
  @spec build_event(atom(), map(), keyword()) :: Event.t()
  def build_event(event_name, data \\ %{}, opts \\ []) do
    event_name
    |> Event.new(data, opts)
    |> Event.to_args()
    |> JSON.encode!()
    |> JSON.decode!()
    |> Event.from_args()
  end

  @doc """
  Build an event with `build_event/3` and pass it to `handler.handle_event/2`.

  Returns whatever the handler returns.
  """
  @spec perform_event(module(), atom(), map(), keyword()) :: term()
  def perform_event(handler, event_name, data \\ %{}, opts \\ []) when is_atom(handler) do
    handler.handle_event(event_name, build_event(event_name, data, opts))
  end

  @doc """
  Convert an `ObanEvents.DispatchWorker` job (or its args) into an `ObanEvents.Event`.
  """
  @spec to_event(Oban.Job.t() | map()) :: Event.t()
  def to_event(%Oban.Job{args: args}), do: to_event(args)

  def to_event(args) when is_map(args) do
    args
    |> JSON.encode!()
    |> JSON.decode!()
    |> Event.from_args()
  end
end
