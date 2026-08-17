defmodule ObanEvents.Testing do
  @moduledoc """
  Test helpers for asserting on events emitted via `ObanEvents`.

  `ObanEvents.emit/2` and `emit/3` attach dynamic metadata (a generated
  `event_id` and `emitted_at` timestamp) to every job, which makes it
  awkward to match on job args directly with `Oban.Testing.assert_enqueued/1`.
  These helpers complement `Oban.Testing` and hide that metadata by
  default, while still letting you build it explicitly when needed (e.g.
  for testing `ObanEvents.DispatchWorker.perform/1` directly).

  ## Usage

      defmodule MyApp.EventsTest do
        use ExUnit.Case, async: true
        use Oban.Testing, repo: MyApp.Repo
        import ObanEvents.Testing

        test "emits user_created for the email handler" do
          {:ok, _user} = MyApp.Accounts.create_user(%{email: "person@example.com"})

          jobs = all_enqueued(worker: ObanEvents.DispatchWorker)

          assert_event_emitted(jobs, :user_created, MyApp.EmailHandler, %{
            "email" => "person@example.com"
          })
        end
      end

  `assert_event_emitted/4` accepts the jobs already fetched via
  `Oban.Testing.all_enqueued/1` (or any other means) rather than fetching
  them itself, so it works regardless of how your test module configures
  `Oban.Testing`.
  """

  import ExUnit.Assertions

  alias ObanEvents.DispatchWorker
  alias ObanEvents.Event

  @doc """
  Build the `ObanEvents.DispatchWorker` job args that `ObanEvents.emit/2`
  would produce for the given event name, handler module, and data --
  without the dynamic `"metadata"` field.

  Handy for asserting job args directly, e.g. with `Oban.Testing.assert_enqueued/1`,
  when the event id and emission timestamp don't matter.

  ## Examples

      assert_enqueued(
        worker: ObanEvents.DispatchWorker,
        args: event_job_args(:user_created, MyApp.EmailHandler, %{"user_id" => 1})
      )
  """
  @spec event_job_args(atom(), module(), map()) :: map()
  def event_job_args(event_name, handler_module, data \\ %{})
      when is_atom(event_name) and is_atom(handler_module) and is_map(data) do
    %{
      "event" => Atom.to_string(event_name),
      "handler" => Atom.to_string(handler_module),
      "data" => data
    }
  end

  @doc """
  Assert that `jobs` contains an `ObanEvents.DispatchWorker` job for the
  given event name, handler module, and data, ignoring dynamic metadata
  (event id, emission timestamp, and any custom metadata).

  `jobs` is typically the result of `Oban.Testing.all_enqueued/1` (e.g.
  `all_enqueued(worker: ObanEvents.DispatchWorker)`), fetched by the caller
  so this helper stays agnostic of how `Oban.Testing` is configured.

  Returns the matching `Oban.Job` struct on success, or raises an
  `ExUnit.AssertionError` with the full list of jobs when no match is found.

  ## Examples

      jobs = all_enqueued(worker: ObanEvents.DispatchWorker)
      assert_event_emitted(jobs, :user_created, MyApp.EmailHandler, %{"user_id" => 1})
  """
  @spec assert_event_emitted([Oban.Job.t()], atom(), module(), map()) :: Oban.Job.t()
  def assert_event_emitted(jobs, event_name, handler_module, data \\ %{})
      when is_list(jobs) and is_atom(event_name) and is_atom(handler_module) and is_map(data) do
    expected = event_job_args(event_name, handler_module, data)

    matching = Enum.find(jobs, &(Map.take(&1.args, ["event", "handler", "data"]) == expected))

    assert matching, """
    Expected an #{inspect(DispatchWorker)} job for event #{inspect(event_name)} \
    with handler #{inspect(handler_module)} and data #{inspect(data)}, but none was found.

    Given jobs: #{inspect(jobs)}
    """

    matching
  end

  @doc """
  Build a deterministic `ObanEvents.Event` fixture for use in tests.

  Unlike `ObanEvents.Event.new/3`, this accepts fixed `:id` and
  `:emitted_at` values (defaulting to stable placeholders) so assertions
  don't need to account for randomly generated ids or timestamps.

  ## Options

  - `:id` - defaults to `"00000000-0000-0000-0000-000000000000"`
  - `:emitted_at` - defaults to `~U[2024-01-01 00:00:00Z]`
  - `:metadata` - additional custom metadata, defaults to `%{}`

  ## Examples

      event = build_event(:user_created, %{"user_id" => 1})
      assert event.id == "00000000-0000-0000-0000-000000000000"
  """
  @spec build_event(atom(), map(), keyword()) :: Event.t()
  def build_event(event_name, data \\ %{}, opts \\ [])
      when is_atom(event_name) and is_map(data) and is_list(opts) do
    id = Keyword.get(opts, :id, "00000000-0000-0000-0000-000000000000")
    emitted_at = Keyword.get(opts, :emitted_at, ~U[2024-01-01 00:00:00Z])
    metadata = Keyword.get(opts, :metadata, %{})

    event = Event.new(event_name, data, metadata)
    %Event{event | id: id, emitted_at: emitted_at}
  end

  @doc """
  Build the job args for `ObanEvents.DispatchWorker.perform/1`, derived
  from a deterministic `build_event/3` fixture.

  Useful for testing `DispatchWorker.perform/1` directly (e.g. via
  `Oban.Testing.perform_job/2`) while still exercising the real
  `ObanEvents.Event.to_job_args/2` serialization.

  ## Examples

      job_args = event_perform_args(:user_created, MyApp.EmailHandler, %{"user_id" => 1})
      assert :ok = perform_job(ObanEvents.DispatchWorker, job_args)
  """
  @spec event_perform_args(atom(), module(), map(), keyword()) :: map()
  def event_perform_args(event_name, handler_module, data \\ %{}, opts \\ [])
      when is_atom(event_name) and is_atom(handler_module) and is_map(data) do
    event_name
    |> build_event(data, opts)
    |> Event.to_job_args(handler_module)
  end
end
