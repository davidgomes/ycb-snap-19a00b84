defmodule ObanEvents.Testing do
  @moduledoc """
  Test helpers for applications using ObanEvents.

  ## Setup

  Use the module in your test case (or case template), passing the same repo
  options you would pass to `Oban.Testing`:

      defmodule MyApp.EventsTest do
        use MyApp.DataCase, async: true
        use ObanEvents.Testing, repo: MyApp.Repo

        # ...
      end

  This imports `build_event/1,2,3` and defines the following functions in the
  test module, with the repo options already applied:

  - `perform_event/2,3,4` - Run a handler through the dispatch worker
  - `assert_event_emitted/1,2` - Assert an event was emitted
  - `refute_event_emitted/1,2` - Refute an event was emitted
  - `all_emitted_events/1,2` - List emitted events as `ObanEvents.Event` structs

  It can be combined with `use Oban.Testing` in the same module. Every helper is
  also available as a plain function on this module, taking the repo options
  (`:repo`, `:prefix`) in `opts`.

  ## Testing Handlers

  Call a handler directly with an event built by `build_event/3`. Data and
  metadata are normalized to string keys, just like a real delivery:

      test "sends a welcome email" do
        event = build_event(:user_created, %{user_id: 123, email: "test@example.com"})

        assert :ok = MyApp.EmailHandler.handle_event(:user_created, event)
      end

  Or run the handler through `ObanEvents.DispatchWorker`, exercising the full
  job serialization path:

      test "sends a welcome email" do
        assert :ok = perform_event(MyApp.EmailHandler, :user_created, %{user_id: 123})
      end

  ## Asserting on Emitted Events

  Emission assertions query enqueued jobs, so Oban must run in `:manual`
  testing mode (jobs are inserted but not executed). With a global `:inline`
  configuration, wrap the code under test in `Oban.Testing.with_testing_mode/2`:

      test "emits user_created" do
        Oban.Testing.with_testing_mode(:manual, fn ->
          {:ok, user} = MyApp.Accounts.create_user(%{email: "test@example.com"})

          assert_event_emitted(:user_created, data: %{user_id: user.id})
          assert_event_emitted(:user_created, handler: MyApp.EmailHandler)
          refute_event_emitted(:user_deleted)

          assert [%ObanEvents.Event{metadata: %{"actor_id" => _}} | _] =
                   all_emitted_events(:user_created)
        end)
      end

  `:data` and `:metadata` are matched partially: only the given keys are checked.
  """

  alias ObanEvents.DispatchWorker
  alias ObanEvents.Event

  @event_keys [:metadata, :event_id, :emitted_at]
  @filter_keys [:handler, :data, :metadata]

  @doc false
  defmacro __using__(repo_opts) do
    unless Keyword.has_key?(repo_opts, :repo) do
      raise ArgumentError, "ObanEvents.Testing requires a :repo option to be set"
    end

    repo_opts = Keyword.put_new(repo_opts, :prefix, false)

    quote do
      import ObanEvents.Testing, only: [build_event: 1, build_event: 2, build_event: 3]

      def perform_event(handler, event_name, data \\ %{}, opts \\ []) do
        opts = Keyword.merge(unquote(repo_opts), opts)
        ObanEvents.Testing.perform_event(handler, event_name, data, opts)
      end

      def assert_event_emitted(event_name, opts \\ []) do
        opts = Keyword.merge(unquote(repo_opts), opts)
        ObanEvents.Testing.assert_event_emitted(event_name, opts)
      end

      def refute_event_emitted(event_name, opts \\ []) do
        opts = Keyword.merge(unquote(repo_opts), opts)
        ObanEvents.Testing.refute_event_emitted(event_name, opts)
      end

      def all_emitted_events(event_name, opts \\ []) do
        opts = Keyword.merge(unquote(repo_opts), opts)
        ObanEvents.Testing.all_emitted_events(event_name, opts)
      end
    end
  end

  @doc """
  Build an `ObanEvents.Event` as a handler would receive it.

  Data and metadata are JSON round-tripped, so keys become strings.

  ## Options

  - `:metadata` - Event metadata map (default: `%{}`)
  - `:event_id` - Event ID (default: a generated UUID)
  - `:emitted_at` - Emission time (default: now)
  - `:job_id` - Job ID (default: a unique integer)
  - `:attempt` - Delivery attempt (default: `1`)

  ## Examples

      iex> event = build_event(:user_created, %{user_id: 1}, metadata: %{actor_id: 2})
      iex> {event.name, event.data, event.metadata, event.attempt}
      {:user_created, %{"user_id" => 1}, %{"actor_id" => 2}, 1}
  """
  @spec build_event(atom(), map(), keyword()) :: Event.t()
  def build_event(event_name, data \\ %{}, opts \\ [])
      when is_atom(event_name) and is_map(data) and is_list(opts) do
    event = new_event(event_name, data, opts)

    %Event{
      event
      | data: json_recode(event.data),
        metadata: json_recode(event.metadata),
        job_id: Keyword.get_lazy(opts, :job_id, fn -> System.unique_integer([:positive]) end),
        attempt: Keyword.get(opts, :attempt, 1)
    }
  end

  @doc """
  Run `handler` for an event through `ObanEvents.DispatchWorker`.

  Builds the same job args `emit/3` would and executes them with
  `Oban.Testing.perform_job/3`, returning the worker result.

  ## Options

  - `:metadata`, `:event_id`, `:emitted_at` - See `build_event/3`
  - Any other option (e.g. `:attempt`, `:repo`, `:prefix`) is passed to
    `Oban.Testing.perform_job/3`

  ## Examples

      assert :ok = perform_event(MyApp.EmailHandler, :user_created, %{user_id: 1})
      assert {:error, _} = perform_event(MyApp.EmailHandler, :user_created, %{}, attempt: 3)
  """
  @spec perform_event(module(), atom(), map(), keyword()) :: Oban.Worker.result()
  def perform_event(handler, event_name, data \\ %{}, opts \\ [])
      when is_atom(handler) and is_atom(event_name) and is_map(data) and is_list(opts) do
    {event_opts, job_opts} = Keyword.split(opts, @event_keys)

    args =
      event_name
      |> new_event(data, event_opts)
      |> Event.to_job_args(handler)

    Oban.Testing.perform_job(DispatchWorker, args, job_opts)
  end

  @doc """
  Assert that an event was emitted, i.e. a matching dispatch job is enqueued.

  ## Options

  - `:handler` - Only match jobs for this handler module
  - `:data` - Map that the event data must contain
  - `:metadata` - Map that the event metadata must contain
  - Any other option (e.g. `:queue`, `:repo`, `:prefix`) is passed to
    `Oban.Testing.assert_enqueued/1`

  ## Examples

      assert_event_emitted(:user_created)
      assert_event_emitted(:user_created, data: %{user_id: user.id}, handler: MyApp.EmailHandler)
  """
  @spec assert_event_emitted(atom(), keyword()) :: true
  def assert_event_emitted(event_name, opts \\ []) when is_atom(event_name) and is_list(opts) do
    event_name
    |> job_filter(opts)
    |> Oban.Testing.assert_enqueued()
  end

  @doc """
  Refute that an event was emitted. Accepts the same options as `assert_event_emitted/2`.

  ## Examples

      refute_event_emitted(:user_deleted)
      refute_event_emitted(:user_created, handler: MyApp.AnalyticsHandler)
  """
  @spec refute_event_emitted(atom(), keyword()) :: false
  def refute_event_emitted(event_name, opts \\ []) when is_atom(event_name) and is_list(opts) do
    event_name
    |> job_filter(opts)
    |> Oban.Testing.refute_enqueued()
  end

  @doc """
  Return emitted events as `ObanEvents.Event` structs, most recent first.

  An event with several handlers appears once per handler. Accepts the same
  options as `assert_event_emitted/2`.

  ## Examples

      assert [%ObanEvents.Event{metadata: %{"actor_id" => ^actor_id}}] =
               all_emitted_events(:user_created, handler: MyApp.EmailHandler)
  """
  @spec all_emitted_events(atom(), keyword()) :: [Event.t()]
  def all_emitted_events(event_name, opts \\ []) when is_atom(event_name) and is_list(opts) do
    event_name
    |> job_filter(opts)
    |> Oban.Testing.all_enqueued()
    |> Enum.map(&Event.from_job/1)
  end

  defp new_event(event_name, data, opts) do
    event = Event.new(event_name, data, Keyword.take(opts, [:metadata]))

    %Event{
      event
      | id: Keyword.get(opts, :event_id, event.id),
        emitted_at: Keyword.get(opts, :emitted_at, event.emitted_at)
    }
  end

  defp job_filter(event_name, opts) do
    {filters, oban_opts} = Keyword.split(opts, @filter_keys)

    args =
      Enum.reduce(filters, %{"event" => Atom.to_string(event_name)}, fn
        {:handler, handler}, acc -> Map.put(acc, "handler", Atom.to_string(handler))
        {:data, data}, acc -> Map.put(acc, "data", data)
        {:metadata, metadata}, acc -> Map.put(acc, "metadata", metadata)
      end)

    Keyword.merge(oban_opts, worker: DispatchWorker, args: args)
  end

  defp json_recode(map), do: map |> JSON.encode!() |> JSON.decode!()
end
