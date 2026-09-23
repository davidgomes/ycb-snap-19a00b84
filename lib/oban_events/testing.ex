defmodule ObanEvents.Testing do
  @moduledoc """
  Helpers for testing event emission and event handlers.

  ## Testing Handlers

  `build_event/3` and `perform_event/4` don't need a database. They build the
  `ObanEvents.Event` a handler receives in production (data and metadata
  JSON round-tripped, so keys are strings):

      import ObanEvents.Testing

      test "sends welcome email" do
        event = build_event(:user_created, %{user_id: 123}, metadata: %{source: "api"})
        assert :ok = MyApp.EmailHandler.handle_event(:user_created, event)
      end

      test "runs the handler through the dispatch worker" do
        assert :ok = perform_event(MyApp.EmailHandler, :user_created, %{user_id: 123})
      end

  ## Testing Emission

  With Oban running in `:manual` testing mode, `use ObanEvents.Testing` with
  your repo to assert on emitted events:

      use ObanEvents.Testing, repo: MyApp.Repo

      test "emits user_created" do
        {:ok, user} = MyApp.Accounts.create_user(%{email: "test@example.com"})

        assert_event_emitted(:user_created, data: %{user_id: user.id})
        assert_event_emitted(:user_created, handler: MyApp.EmailHandler)
        refute_event_emitted(:user_deleted)

        assert [%ObanEvents.Event{name: :user_created}] = all_emitted_events(:user_created)
      end

  Pass `prefix:` alongside `repo:` if Oban uses a non-default prefix.

  ### Matching Options

  `assert_event_emitted/2` and `refute_event_emitted/2` accept:

  - `:data` - Map the event data must contain (partial, deep match)
  - `:metadata` - Map the event metadata must contain (partial, deep match)
  - `:handler` - Handler module the event was dispatched to
  - `:causation_id` - Expected causation id
  - `:correlation_id` - Expected correlation id
  """

  alias ObanEvents.{DispatchWorker, Event}

  @match_keys [:data, :metadata, :handler, :causation_id, :correlation_id]

  @doc false
  defmacro __using__(opts) do
    unless Keyword.has_key?(opts, :repo) do
      raise ArgumentError, "ObanEvents.Testing requires a :repo option to be set"
    end

    repo_opts = Keyword.put_new(opts, :prefix, false)

    quote do
      import ObanEvents.Testing,
        only: [build_event: 1, build_event: 2, build_event: 3, perform_event: 3, perform_event: 4]

      def assert_event_emitted(event_name, opts \\ []) do
        ObanEvents.Testing.assert_event_emitted(unquote(repo_opts), event_name, opts)
      end

      def refute_event_emitted(event_name, opts \\ []) do
        ObanEvents.Testing.refute_event_emitted(unquote(repo_opts), event_name, opts)
      end

      def all_emitted_events(event_name, opts \\ []) do
        ObanEvents.Testing.all_emitted_events(unquote(repo_opts), event_name, opts)
      end
    end
  end

  @doc """
  Build an `ObanEvents.Event` as a handler would receive it.

  Accepts the same options as `ObanEvents.Event.new/3`. Data and metadata are
  JSON round-tripped, so atoms, dates, and other JSON-encodable values arrive
  as they would after being stored in the database.
  """
  @spec build_event(atom(), map(), [Event.option()]) :: Event.t()
  def build_event(event_name, data \\ %{}, opts \\ []) do
    event = Event.new(event_name, data, opts)
    %{event | data: json_recode(event.data), metadata: json_recode(event.metadata)}
  end

  @doc """
  Run `handler` for an event through `ObanEvents.DispatchWorker`, without
  inserting a job.

  Returns the worker's result: `:ok` on success (including `{:ok, result}` and
  unexpected handler returns) or `{:error, reason}`. Exceptions raised by the
  handler propagate.
  """
  @spec perform_event(module(), atom(), map(), [Event.option()]) :: :ok | {:error, any()}
  def perform_event(handler, event_name, data, opts \\ []) when is_atom(handler) do
    args =
      event_name
      |> Event.new(data, opts)
      |> Event.to_args(handler)
      |> json_recode()

    DispatchWorker.perform(%Oban.Job{worker: inspect(DispatchWorker), args: args})
  end

  @doc false
  @spec assert_event_emitted(Keyword.t(), atom(), Keyword.t()) :: true
  def assert_event_emitted(repo_opts, event_name, opts \\ []) do
    repo_opts
    |> job_opts(event_name, opts)
    |> Oban.Testing.assert_enqueued()
  end

  @doc false
  @spec refute_event_emitted(Keyword.t(), atom(), Keyword.t()) :: false
  def refute_event_emitted(repo_opts, event_name, opts \\ []) do
    repo_opts
    |> job_opts(event_name, opts)
    |> Oban.Testing.refute_enqueued()
  end

  @doc false
  @spec all_emitted_events(Keyword.t(), atom(), Keyword.t()) :: [Event.t()]
  def all_emitted_events(repo_opts, event_name, opts \\ []) do
    repo_opts
    |> job_opts(event_name, opts)
    |> Oban.Testing.all_enqueued()
    |> Enum.map(&Event.from_args(event_name, &1.args))
    |> Enum.uniq_by(&(&1.event_id || make_ref()))
  end

  defp job_opts(repo_opts, event_name, opts) when is_atom(event_name) do
    case Keyword.keys(opts) -- @match_keys do
      [] -> :ok
      unknown -> raise ArgumentError, "unknown options: #{inspect(unknown)}"
    end

    args =
      Enum.reduce(opts, %{"event" => Atom.to_string(event_name)}, fn
        {:handler, handler}, acc -> Map.put(acc, "handler", Atom.to_string(handler))
        {key, value}, acc -> Map.put(acc, Atom.to_string(key), json_recode(value))
      end)

    Keyword.merge(repo_opts, worker: DispatchWorker, args: args)
  end

  defp json_recode(value), do: value |> Jason.encode!() |> Jason.decode!()
end
