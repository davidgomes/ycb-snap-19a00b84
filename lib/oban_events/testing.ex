defmodule ObanEvents.Testing do
  @moduledoc """
  Helpers for testing event emission and event handlers.

  Add the helpers to a test case with `use`, passing the same options you would
  pass to `Oban.Testing`:

      defmodule MyApp.AccountsTest do
        use ExUnit.Case, async: true
        use ObanEvents.Testing, repo: MyApp.Repo

        test "creating a user emits an event" do
          {:ok, user} = Accounts.create_user(%{email: "test@example.com"})

          assert_event_emitted(:user_created,
            handler: MyApp.EmailHandler,
            data: %{user_id: user.id}
          )
        end
      end

  `use ObanEvents.Testing` also does `use Oban.Testing`, so `assert_enqueued/1`,
  `all_enqueued/1`, `perform_job/3` and friends remain available for assertions
  that the event helpers don't cover.

  ## Asserting on Emitted Events

  `assert_event_emitted/2` and `refute_event_emitted/2` match against the jobs
  `ObanEvents` enqueues, and only against the fields you pass:

      assert_event_emitted(:user_created)
      assert_event_emitted(:user_created, handler: MyApp.EmailHandler)
      assert_event_emitted(:user_created, data: %{user_id: 1}, meta: %{actor_id: 7})
      refute_event_emitted(:user_deleted)

  `emitted_events/1` returns the emitted events as `ObanEvents.Event` structs,
  which is handy for asserting on generated metadata:

      assert [%ObanEvents.Event{} = event] = emitted_events()
      assert event.name == :user_created
      assert event.meta["actor_id"] == 7

  ## Testing Handlers

  `perform_event/4` runs a handler through `ObanEvents.DispatchWorker`, the same
  way Oban does in production, including the metadata the handler receives:

      assert :ok =
               perform_event(MyApp.AuditHandler, :user_created, %{user_id: 1},
                 meta: %{actor_id: 7}
               )

  For handlers that are called directly, `build_event/3` builds the
  `ObanEvents.Event` struct they receive as the third argument:

      event = build_event(:user_created, %{user_id: 1}, meta: %{actor_id: 7})

      assert :ok = MyApp.AuditHandler.handle_event(event.name, event.data, event)
  """

  alias ObanEvents.Event

  @job_opts [:attempt, :max_attempts, :priority, :queue, :scheduled_at]

  @doc false
  defmacro __using__(opts) do
    quote do
      use Oban.Testing, unquote(opts)

      import ObanEvents.Testing
    end
  end

  @doc """
  Build the `ObanEvents.Event` struct a handler receives for an event.

  Accepts the same options as `ObanEvents.Event.new/3`, so `:meta`, `:id` and
  `:emitted_at` can be pinned to make assertions deterministic.

  ## Examples

      event = build_event(:user_created, %{user_id: 1}, meta: %{actor_id: 7})

      assert :ok = MyApp.AuditHandler.handle_event(event.name, event.data, event)
  """
  @spec build_event(atom(), map(), keyword()) :: Event.t()
  def build_event(name, data \\ %{}, opts \\ []) do
    Event.new(name, data, opts)
  end

  @doc """
  Build the Oban job args that an emitted event is stored with.

  Only the fields passed in `opts` are included, which makes the result usable
  as a partial match for `Oban.Testing.assert_enqueued/1`.

  ## Options

  - `:handler` - handler module the event is dispatched to
  - `:data` - event payload, keys are normalized to strings
  - `:meta` - event metadata, keys are normalized to strings
  - `:id` - unique event id

  ## Examples

      iex> ObanEvents.Testing.event_args(:user_created, data: %{user_id: 1})
      %{"event" => "user_created", "data" => %{"user_id" => 1}}
  """
  @spec event_args(atom(), keyword()) :: map()
  def event_args(name, opts \\ []) when is_atom(name) and is_list(opts) do
    Enum.reduce(opts, %{"event" => Atom.to_string(name)}, fn
      {:handler, handler}, args when is_atom(handler) ->
        Map.put(args, "handler", Atom.to_string(handler))

      {:data, data}, args ->
        Map.put(args, "data", Event.normalize_payload(data))

      {:meta, meta}, args ->
        Map.put(args, "meta", Event.normalize_payload(meta))

      {:id, id}, args ->
        Map.put(args, "event_id", id)

      {key, _value}, _args ->
        raise ArgumentError,
              "unknown event option #{inspect(key)}, expected one of :handler, :data, :meta or :id"
    end)
  end

  @doc """
  Build the full Oban job args for an event dispatched to `handler`.

  Unlike `event_args/2` this includes the generated metadata, so it describes a
  job exactly as `emit/3` would have inserted it.
  """
  @spec event_job_args(module(), atom(), map(), keyword()) :: map()
  def event_job_args(handler, name, data \\ %{}, opts \\ []) do
    name
    |> build_event(data, opts)
    |> Event.for_handler(handler)
    |> Event.to_args()
  end

  @doc """
  Assert that an event was emitted.

  Matches against jobs enqueued for `ObanEvents.DispatchWorker`, using the
  fields described in `event_args/2`.

  ## Examples

      assert_event_emitted(:user_created)
      assert_event_emitted(:user_created, handler: MyApp.EmailHandler, data: %{user_id: 1})
  """
  defmacro assert_event_emitted(name, opts \\ []) do
    quote do
      assert_enqueued(
        worker: ObanEvents.DispatchWorker,
        args: ObanEvents.Testing.event_args(unquote(name), unquote(opts))
      )
    end
  end

  @doc """
  Refute that an event was emitted.

  Takes the same options as `assert_event_emitted/2`.

  ## Examples

      refute_event_emitted(:user_deleted)
      refute_event_emitted(:user_created, handler: MyApp.EmailHandler)
  """
  defmacro refute_event_emitted(name, opts \\ []) do
    quote do
      refute_enqueued(
        worker: ObanEvents.DispatchWorker,
        args: ObanEvents.Testing.event_args(unquote(name), unquote(opts))
      )
    end
  end

  @doc """
  Return all emitted events as `ObanEvents.Event` structs.

  Options are passed to `Oban.Testing.all_enqueued/1`, e.g. `queue: :events`.
  Jobs that don't describe an event are skipped.

  ## Examples

      assert [%ObanEvents.Event{} = event] = emitted_events()
      assert event.name == :user_created
  """
  defmacro emitted_events(opts \\ []) do
    quote do
      unquote(opts)
      |> Keyword.put(:worker, ObanEvents.DispatchWorker)
      |> all_enqueued()
      |> Enum.flat_map(fn job ->
        case ObanEvents.Event.from_job(job) do
          {:ok, event} -> [event]
          :error -> []
        end
      end)
    end
  end

  @doc """
  Run `handler` for an event through `ObanEvents.DispatchWorker`.

  The event is built with `build_event/3`, so `:meta`, `:id` and `:emitted_at`
  can be passed to control the metadata the handler receives. Oban job options
  (`#{inspect(@job_opts)}`) are forwarded to the job the handler runs in.

  Returns the worker result, e.g. `:ok` or `{:error, reason}`.

  ## Examples

      assert :ok = perform_event(MyApp.EmailHandler, :user_created, %{user_id: 1})

      assert :ok =
               perform_event(MyApp.AuditHandler, :user_created, %{user_id: 1},
                 meta: %{actor_id: 7},
                 attempt: 3
               )
  """
  defmacro perform_event(handler, name, data \\ %{}, opts \\ []) do
    job_opts = @job_opts

    quote bind_quoted: [handler: handler, name: name, data: data, opts: opts, job_opts: job_opts] do
      perform_job(
        ObanEvents.DispatchWorker,
        ObanEvents.Testing.event_job_args(handler, name, data, opts),
        Keyword.take(opts, job_opts)
      )
    end
  end
end
