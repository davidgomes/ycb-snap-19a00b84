defmodule ObanEvents.Testing do
  @moduledoc """
  Test helpers for asserting that events were emitted via `ObanEvents`.

  These helpers wrap `Oban.Testing.assert_enqueued/2` and
  `Oban.Testing.refute_enqueued/2` with the job argument shape that
  `ObanEvents.DispatchWorker` expects, so tests don't need to know about the
  underlying job args directly.

  ## Usage

      import ObanEvents.Testing

      test "emits user_created for the email handler" do
        {:ok, _jobs} = MyApp.Events.emit(:user_created, %{user_id: 1})

        assert_event_emitted(MyApp.Repo, :user_created, MyApp.EmailHandler)
      end

  Narrow the match by passing `:data` and/or `:metadata`:

      assert_event_emitted(MyApp.Repo, :user_created, MyApp.EmailHandler,
        data: %{"user_id" => 1},
        metadata: %{"source" => "signup_form"}
      )

  Any other option accepted by `Oban.Testing.assert_enqueued/2` (such as
  `:queue`) may also be passed through.
  """

  alias ObanEvents.DispatchWorker

  @doc """
  Assert that an event was enqueued for the given handler.

  See the module documentation for supported options.
  """
  @spec assert_event_emitted(module(), atom(), module(), keyword()) :: true
  def assert_event_emitted(repo, event_name, handler, opts \\ [])
      when is_atom(event_name) and is_atom(handler) do
    Oban.Testing.assert_enqueued(repo, build_opts(event_name, handler, opts))
  end

  @doc """
  Refute that an event was enqueued for the given handler.

  See the module documentation for supported options.
  """
  @spec refute_event_emitted(module(), atom(), module(), keyword()) :: true
  def refute_event_emitted(repo, event_name, handler, opts \\ [])
      when is_atom(event_name) and is_atom(handler) do
    Oban.Testing.refute_enqueued(repo, build_opts(event_name, handler, opts))
  end

  @doc """
  Build the `ObanEvents.DispatchWorker` job args that would be produced by
  emitting `event_name` for `handler` with the given `data` and `metadata`.

  Useful when composing assertions manually (e.g. with `all_enqueued/1` from
  `Oban.Testing`) instead of using `assert_event_emitted/4`.
  """
  @spec build_event_args(atom(), module(), map(), map()) :: map()
  def build_event_args(event_name, handler, data \\ %{}, metadata \\ %{})
      when is_atom(event_name) and is_atom(handler) and is_map(data) and is_map(metadata) do
    %{
      "event" => Atom.to_string(event_name),
      "handler" => Atom.to_string(handler),
      "data" => data,
      "metadata" => metadata
    }
  end

  defp build_opts(event_name, handler, opts) do
    {data, opts} = Keyword.pop(opts, :data)
    {metadata, opts} = Keyword.pop(opts, :metadata)

    args =
      %{"event" => Atom.to_string(event_name), "handler" => Atom.to_string(handler)}
      |> maybe_put("data", data)
      |> maybe_put("metadata", metadata)

    Keyword.merge(opts, worker: DispatchWorker, args: args)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
