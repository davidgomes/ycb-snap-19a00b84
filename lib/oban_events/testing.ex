defmodule ObanEvents.Testing do
  @moduledoc """
  Testing helpers for applications using `ObanEvents`.

  This module provides assertion and inspection helpers to test event emission,
  inspect enqueued event jobs, and assert against events with metadata and payloads.

  ## Usage

  Use this module in your test files or case templates:

      defmodule MyApp.EventsTest do
        use ExUnit.Case
        use ObanEvents.Testing, repo: MyApp.Repo

        test "emits user_created event" do
          MyApp.Events.emit(:user_created, %{user_id: 123})

          assert_event_emitted(:user_created)
          assert_event_emitted(:user_created, %{user_id: 123})
        end
      end

  ## Options

  - `:repo` - The Ecto Repo module used by Oban (required for querying jobs in `:manual` mode).
  - `:prefix` - PostgreSQL schema / Ecto prefix (default: `false` / `"public"`).
  """

  alias ObanEvents.Event

  defmacro __using__(opts) do
    quote do
      use Oban.Testing, unquote(opts)

      @oban_events_testing_opts unquote(opts)

      def assert_event_emitted(event_name, data_or_opts \\ %{}, timeout_or_opts \\ :none) do
        ObanEvents.Testing.assert_event_emitted(
          @oban_events_testing_opts,
          event_name,
          data_or_opts,
          timeout_or_opts
        )
      end

      def refute_event_emitted(event_name, data_or_opts \\ %{}, timeout_or_opts \\ :none) do
        ObanEvents.Testing.refute_event_emitted(
          @oban_events_testing_opts,
          event_name,
          data_or_opts,
          timeout_or_opts
        )
      end

      def all_emitted_events(opts \\ []) do
        @oban_events_testing_opts
        |> Keyword.merge(opts)
        |> ObanEvents.Testing.all_emitted_events()
      end
    end
  end

  @doc """
  Asserts that an event was emitted with the given event name, and optionally matching data, metadata, or other fields.

  ## Examples

      # Assert event name was emitted
      assert_event_emitted(:user_created)

      # Assert event with specific data
      assert_event_emitted(:user_created, %{user_id: 123})

      # Assert event with specific handler, metadata, or other options
      assert_event_emitted(:user_created, %{user_id: 123}, handler: MyApp.EmailHandler)
      assert_event_emitted(:user_created, %{}, correlation_id: "corr-123")

      # Timeout in milliseconds for async waiting
      assert_event_emitted(:user_created, %{user_id: 123}, 100)
  """
  def assert_event_emitted(repo_opts, event_name, data_or_opts, timeout_or_opts)

  def assert_event_emitted(repo_opts, event_name, data, timeout)
      when is_integer(timeout) and timeout > 0 do
    match_opts = build_match_opts(event_name, data, [])
    full_opts = Keyword.merge(repo_opts, match_opts)

    Oban.Testing.assert_enqueued(full_opts, timeout)
  end

  def assert_event_emitted(repo_opts, event_name, data, extra_opts)
      when is_list(extra_opts) do
    match_opts = build_match_opts(event_name, data, extra_opts)
    full_opts = Keyword.merge(repo_opts, match_opts)

    Oban.Testing.assert_enqueued(full_opts)
  end

  def assert_event_emitted(repo_opts, event_name, data_or_opts, :none) do
    {data, extra_opts} =
      if is_list(data_or_opts) do
        {%{}, data_or_opts}
      else
        {data_or_opts, []}
      end

    match_opts = build_match_opts(event_name, data, extra_opts)
    full_opts = Keyword.merge(repo_opts, match_opts)

    Oban.Testing.assert_enqueued(full_opts)
  end

  @doc """
  Refutes that an event was emitted matching the given criteria.

  ## Examples

      refute_event_emitted(:user_deleted)
      refute_event_emitted(:user_created, %{user_id: 999})
      refute_event_emitted(:user_created, %{}, handler: MyApp.UnexpectedHandler)
  """
  def refute_event_emitted(repo_opts, event_name, data_or_opts, timeout_or_opts)

  def refute_event_emitted(repo_opts, event_name, data, timeout)
      when is_integer(timeout) and timeout > 0 do
    match_opts = build_match_opts(event_name, data, [])
    full_opts = Keyword.merge(repo_opts, match_opts)

    Oban.Testing.refute_enqueued(full_opts, timeout)
  end

  def refute_event_emitted(repo_opts, event_name, data, extra_opts)
      when is_list(extra_opts) do
    match_opts = build_match_opts(event_name, data, extra_opts)
    full_opts = Keyword.merge(repo_opts, match_opts)

    Oban.Testing.refute_enqueued(full_opts)
  end

  def refute_event_emitted(repo_opts, event_name, data_or_opts, :none) do
    {data, extra_opts} =
      if is_list(data_or_opts) do
        {%{}, data_or_opts}
      else
        {data_or_opts, []}
      end

    match_opts = build_match_opts(event_name, data, extra_opts)
    full_opts = Keyword.merge(repo_opts, match_opts)

    Oban.Testing.refute_enqueued(full_opts)
  end

  @doc """
  Returns a list of all emitted events currently enqueued as `ObanEvents.Event` structs.
  Can be filtered by event name or other job options.

  ## Examples

      events = all_emitted_events()
      events = all_emitted_events(event: :user_created)
  """
  def all_emitted_events(opts \\ []) do
    {event_filter, oban_opts} = Keyword.pop(opts, :event)
    oban_opts = Keyword.put_new(oban_opts, :worker, ObanEvents.DispatchWorker)

    jobs = Oban.Testing.all_enqueued(oban_opts)

    events =
      Enum.map(jobs, fn job ->
        Event.from_map(job.args)
      end)

    if event_filter do
      target_name =
        if is_binary(event_filter), do: String.to_atom(event_filter), else: event_filter

      Enum.filter(events, &(&1.name == target_name))
    else
      events
    end
  end

  defp build_match_opts(event_name, data, extra_opts) do
    event_str = to_string(event_name)

    # Base args to match inside Oban job args
    args_match = %{"event" => event_str}

    args_match =
      if is_map(data) and map_size(data) > 0 do
        Map.put(args_match, "data", stringify_keys(data))
      else
        args_match
      end

    # Check for metadata, correlation_id, causation_id in extra_opts
    {handler, extra_opts} = Keyword.pop(extra_opts, :handler)
    {correlation_id, extra_opts} = Keyword.pop(extra_opts, :correlation_id)
    {causation_id, extra_opts} = Keyword.pop(extra_opts, :causation_id)
    {metadata, extra_opts} = Keyword.pop(extra_opts, :metadata)
    {id, extra_opts} = Keyword.pop(extra_opts, :id)

    args_match =
      if handler do
        Map.put(args_match, "handler", Atom.to_string(handler))
      else
        args_match
      end

    args_match =
      if correlation_id do
        Map.put(args_match, "correlation_id", correlation_id)
      else
        args_match
      end

    args_match =
      if causation_id do
        Map.put(args_match, "causation_id", causation_id)
      else
        args_match
      end

    args_match =
      if metadata do
        Map.put(args_match, "metadata", stringify_keys(metadata))
      else
        args_match
      end

    args_match =
      if id do
        Map.put(args_match, "id", id)
      else
        args_match
      end

    [worker: ObanEvents.DispatchWorker, args: args_match] ++ extra_opts
  end

  defp stringify_keys(%_{} = struct), do: struct

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), stringify_keys(v)} end)
  end

  defp stringify_keys(list) when is_list(list) do
    Enum.map(list, &stringify_keys/1)
  end

  defp stringify_keys(other), do: other
end
