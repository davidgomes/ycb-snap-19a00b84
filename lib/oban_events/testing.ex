defmodule ObanEvents.Testing do
  @moduledoc """
  Helpers for testing event handlers and emission.

      import ObanEvents.Testing

      test "handles user_created" do
        event = build_event(:user_created, %{user_id: 1}, metadata: %{actor_id: 2})
        assert :ok = MyApp.EmailHandler.handle_event(event.name, event)
      end

      test "dispatches through the worker" do
        assert :ok = perform_event(MyApp.EmailHandler, :user_created, %{user_id: 1})
      end

  Data and metadata are JSON round-tripped so handlers see string keys,
  exactly as they would in production.
  """

  alias ObanEvents.{DispatchWorker, Event}

  @doc """
  Builds an `ObanEvents.Event` as a handler would receive it.

  Accepts the same options as `ObanEvents.Event.new/3`.
  """
  @spec build_event(atom(), map(), keyword()) :: Event.t()
  def build_event(name, data \\ %{}, opts \\ []) do
    opts = Keyword.update(opts, :metadata, %{}, &json_roundtrip/1)
    Event.new(name, json_roundtrip(data), opts)
  end

  @doc """
  Runs `handler` for an event through `ObanEvents.DispatchWorker.perform/1`.
  """
  @spec perform_event(module(), atom(), map(), keyword()) :: term()
  def perform_event(handler, name, data \\ %{}, opts \\ []) do
    args =
      name
      |> build_event(data, opts)
      |> Event.to_args(handler)
      |> json_roundtrip()

    DispatchWorker.perform(%Oban.Job{args: args, worker: inspect(DispatchWorker)})
  end

  @doc """
  Returns the job args an event bus would enqueue for `handler`, useful with
  `Oban.Testing.assert_enqueued/1`. Only the stable keys are included.
  """
  @spec event_args(atom(), module(), map()) :: map()
  def event_args(name, handler, data \\ %{}) do
    %{
      "event" => Atom.to_string(name),
      "handler" => Atom.to_string(handler),
      "data" => json_roundtrip(data)
    }
  end

  defp json_roundtrip(term), do: term |> Jason.encode!() |> Jason.decode!()
end
