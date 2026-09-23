defmodule ObanEvents.Testing do
  @moduledoc """
  Helpers for testing event handlers and event emission.

      defmodule MyApp.EmailHandlerTest do
        use ExUnit.Case, async: true
        import ObanEvents.Testing

        test "sends welcome email" do
          assert :ok = call_handler(MyApp.EmailHandler, :user_created, %{user_id: 1})
        end
      end

  Assertions on enqueued events require `use Oban.Testing, repo: MyApp.Repo`
  in the test module (with `testing: :manual`).
  """

  import ExUnit.Assertions

  alias ObanEvents.Event

  @doc """
  Builds an `ObanEvents.Event` as a handler would receive it.

  Keys of `data` and `:metadata` are converted to strings. Accepts the same
  options as `ObanEvents.Event.new/3`.
  """
  @spec build_event(atom(), map(), keyword()) :: Event.t()
  def build_event(name, data \\ %{}, opts \\ []) do
    Event.new(name, data, opts)
  end

  @doc """
  Invokes `handler.handle_event/2` with an event built by `build_event/3`.
  """
  @spec call_handler(module(), atom(), map(), keyword()) :: term()
  def call_handler(handler, name, data \\ %{}, opts \\ []) do
    event = build_event(name, data, Keyword.put(opts, :handler, handler))
    handler.handle_event(name, event)
  end

  @doc """
  Returns the `ObanEvents.Event` structs for the given jobs (e.g. as returned by `emit/3`
  or `Oban.Testing.all_enqueued/1`).
  """
  @spec events_from_jobs([Oban.Job.t()]) :: [Event.t()]
  def events_from_jobs(jobs) do
    Enum.map(jobs, fn %Oban.Job{args: %{"event" => name, "handler" => handler}} = job ->
      Event.from_job(job, String.to_existing_atom(name), String.to_existing_atom(handler))
    end)
  end

  @doc """
  Asserts that `event_name` was emitted (enqueued), optionally for a specific
  `:handler` and with a `:data` / `:metadata` subset. Returns the matching events.

      assert_event_emitted(MyApp.Repo, :user_created, data: %{user_id: 1})
  """
  @spec assert_event_emitted(module(), atom(), keyword()) :: [Event.t()]
  def assert_event_emitted(repo, event_name, opts \\ []) do
    events = matching_events(repo, event_name, opts)

    assert events != [],
           "Expected event #{inspect(event_name)} to be emitted with #{inspect(opts)}, " <>
             "but no matching job was enqueued"

    events
  end

  @doc """
  Refutes that `event_name` was emitted. Accepts the same options as
  `assert_event_emitted/3`.
  """
  @spec refute_event_emitted(module(), atom(), keyword()) :: :ok
  def refute_event_emitted(repo, event_name, opts \\ []) do
    events = matching_events(repo, event_name, opts)

    assert events == [],
           "Expected event #{inspect(event_name)} not to be emitted with #{inspect(opts)}, " <>
             "but found #{length(events)} matching job(s)"

    :ok
  end

  defp matching_events(repo, event_name, opts) do
    data = stringify(Keyword.get(opts, :data, %{}))
    metadata = stringify(Keyword.get(opts, :metadata, %{}))
    handler = Keyword.get(opts, :handler)

    [repo: repo]
    |> Oban.Testing.all_enqueued(worker: ObanEvents.DispatchWorker)
    |> Enum.filter(&(&1.args["event"] == Atom.to_string(event_name)))
    |> Enum.filter(&(is_nil(handler) or &1.args["handler"] == Atom.to_string(handler)))
    |> events_from_jobs()
    |> Enum.filter(&(subset?(data, &1.data) and subset?(metadata, &1.metadata)))
  end

  defp subset?(expected, actual) do
    Enum.all?(expected, fn {k, v} -> Map.fetch(actual, k) == {:ok, v} end)
  end

  defp stringify(map), do: map |> Jason.encode!() |> Jason.decode!()
end
