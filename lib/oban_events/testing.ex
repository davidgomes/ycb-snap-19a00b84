defmodule ObanEvents.Testing do
  @moduledoc """
  Test helpers for applications using `ObanEvents`.

  ## Setup

      defmodule MyApp.AccountsTest do
        use MyApp.DataCase
        use ObanEvents.Testing, repo: MyApp.Repo

        test "emits user_created" do
          {:ok, user} = MyApp.Accounts.create_user(%{email: "test@example.com"})

          assert_event_emitted(:user_created, %{user_id: user.id})
        end
      end

  `use ObanEvents.Testing` accepts the same options as `use Oban.Testing`
  (`:repo` is required, `:prefix` is optional) and can be combined with it.

  It defines the following helpers in the test module:

  - `assert_event_emitted/1,2,3` - Assert a matching event was emitted, returns the `ObanEvents.Event`
  - `refute_event_emitted/1,2,3` - Refute that a matching event was emitted
  - `all_emitted_events/0,1` - List emitted events, optionally filtered by name
  - `perform_event/2,3,4` - Run a handler through `ObanEvents.DispatchWorker`

  and imports `build_event/1,2,3`.

  The emission helpers (`assert_event_emitted`, `refute_event_emitted`, and
  `all_emitted_events`) inspect enqueued jobs, so they require Oban's
  `testing: :manual` mode (or `Oban.Testing.with_testing_mode(:manual, fun)`).
  In `:inline` mode jobs execute immediately and are never enqueued.

  ## Matching

  Data and metadata are matched as subsets after JSON normalization, so atom
  and string keys are interchangeable and only the given keys are compared:

      assert_event_emitted(:user_created, %{user_id: 123})
      assert_event_emitted(:user_created, %{}, metadata: %{source: "signup"})
      assert_event_emitted(:invoice_requested, %{}, causation_id: order_event.event_id)

  Supported options: `:metadata`, `:causation_id`, `:correlation_id`, `:event_id`.
  """

  alias ObanEvents.{DispatchWorker, Event}

  @match_keys [:event_id, :causation_id, :correlation_id]

  defmacro __using__(repo_opts) do
    unless Keyword.has_key?(repo_opts, :repo) do
      raise ArgumentError, "ObanEvents.Testing requires a :repo option to be set"
    end

    quote do
      import ObanEvents.Testing, only: [build_event: 1, build_event: 2, build_event: 3]

      @oban_events_testing_opts Keyword.put_new(unquote(repo_opts), :prefix, false)

      def assert_event_emitted(event_name, data \\ %{}, opts \\ []) do
        ObanEvents.Testing.assert_event_emitted(
          @oban_events_testing_opts,
          event_name,
          data,
          opts
        )
      end

      def refute_event_emitted(event_name, data \\ %{}, opts \\ []) do
        ObanEvents.Testing.refute_event_emitted(
          @oban_events_testing_opts,
          event_name,
          data,
          opts
        )
      end

      def all_emitted_events(event_name \\ nil) do
        ObanEvents.Testing.all_emitted_events(@oban_events_testing_opts, event_name)
      end

      def perform_event(handler, event_name, data \\ %{}, opts \\ []) do
        ObanEvents.Testing.perform_event(
          @oban_events_testing_opts,
          handler,
          event_name,
          data,
          opts
        )
      end
    end
  end

  @doc """
  Build an `ObanEvents.Event` exactly as a handler would receive it.

  Data and metadata are JSON-normalized (string keys, JSON-compatible values),
  which makes this useful for calling `handle_event/2` directly in unit tests.

  Accepts the same options as `emit/3`: `:causation_id`, `:correlation_id`,
  and `:metadata`.

      event = build_event(:user_created, %{user_id: 123}, metadata: %{source: "test"})
      assert :ok = MyApp.EmailHandler.handle_event(:user_created, event)
  """
  @spec build_event(atom(), map(), keyword()) :: Event.t()
  def build_event(event_name, data \\ %{}, opts \\ []) do
    %{
      Event.new(event_name, data, opts)
      | data: normalize(data),
        metadata: normalize(Keyword.get(opts, :metadata, %{}))
    }
  end

  @doc """
  Run `handler` for an event through `ObanEvents.DispatchWorker`.

  The event is serialized into job args and executed with
  `Oban.Testing.perform_job/3`, mirroring production dispatch. Returns the
  worker result (`:ok` or `{:error, reason}`).

  Accepts the same event options as `emit/3`.
  """
  @spec perform_event(keyword(), module(), atom(), map(), keyword()) :: Oban.Worker.result()
  def perform_event(conf_opts, handler, event_name, data \\ %{}, opts \\ [])
      when is_atom(handler) and is_atom(event_name) and is_map(data) do
    args =
      event_name
      |> Event.new(data, opts)
      |> Event.to_job_args(handler)

    Oban.Testing.perform_job(DispatchWorker, args, conf_opts)
  end

  @doc """
  List events emitted (enqueued) so far, optionally filtered by `event_name`.

  Each emission is returned once, regardless of how many handlers it was
  dispatched to.
  """
  @spec all_emitted_events(keyword(), atom() | nil) :: [Event.t()]
  def all_emitted_events(conf_opts, event_name \\ nil) do
    conf_opts
    |> Keyword.put(:worker, DispatchWorker)
    |> Oban.Testing.all_enqueued()
    |> to_events()
    |> Enum.filter(&(is_nil(event_name) or &1.event_name == event_name))
  end

  @doc """
  Assert that an event matching `event_name`, `data`, and `opts` was emitted.

  Returns the first matching `ObanEvents.Event`.
  """
  @spec assert_event_emitted(keyword(), atom(), map(), keyword()) :: Event.t()
  def assert_event_emitted(conf_opts, event_name, data \\ %{}, opts \\ []) do
    events = all_emitted_events(conf_opts, event_name)

    case Enum.find(events, &matches?(&1, data, opts)) do
      nil ->
        raise ExUnit.AssertionError,
          message: """
          Expected an event matching:

          #{inspect(expected(event_name, data, opts), pretty: true)}

          Emitted #{inspect(event_name)} events:

          #{inspect(events, pretty: true)}
          """

      event ->
        event
    end
  end

  @doc """
  Refute that an event matching `event_name`, `data`, and `opts` was emitted.
  """
  @spec refute_event_emitted(keyword(), atom(), map(), keyword()) :: true
  def refute_event_emitted(conf_opts, event_name, data \\ %{}, opts \\ []) do
    case Enum.filter(all_emitted_events(conf_opts, event_name), &matches?(&1, data, opts)) do
      [] ->
        true

      matching ->
        raise ExUnit.AssertionError,
          message: """
          Expected no events matching:

          #{inspect(expected(event_name, data, opts), pretty: true)}

          Found:

          #{inspect(matching, pretty: true)}
          """
    end
  end

  @doc """
  Convert `ObanEvents.DispatchWorker` jobs into events, one per emission.

  Useful with jobs returned by `emit/3` or `Oban.Testing.all_enqueued/1`.
  """
  @spec to_events([Oban.Job.t()]) :: [Event.t()]
  def to_events(jobs) when is_list(jobs) do
    jobs
    |> Enum.filter(&(&1.worker == inspect(DispatchWorker)))
    |> Enum.sort_by(& &1.id)
    |> Enum.map(fn %Oban.Job{args: args} ->
      args = normalize(args)
      Event.from_job_args(String.to_existing_atom(args["event"]), args)
    end)
    |> Enum.uniq_by(&(&1.event_id || make_ref()))
  end

  defp matches?(%Event{} = event, data, opts) do
    subset?(normalize(data), event.data) and
      subset?(normalize(Keyword.get(opts, :metadata, %{})), event.metadata) and
      Enum.all?(Keyword.take(opts, @match_keys), fn {key, value} ->
        Map.fetch!(event, key) == value
      end)
  end

  defp subset?(expected, actual) when is_map(expected) and is_map(actual) do
    Enum.all?(expected, fn {key, value} ->
      Map.has_key?(actual, key) and subset?(value, Map.fetch!(actual, key))
    end)
  end

  defp subset?(expected, actual), do: expected == actual

  defp expected(event_name, data, opts) do
    Map.merge(%{event_name: event_name, data: data}, Map.new(opts))
  end

  defp normalize(term), do: term |> JSON.encode!() |> JSON.decode!()
end
