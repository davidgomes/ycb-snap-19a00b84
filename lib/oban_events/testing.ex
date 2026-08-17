defmodule ObanEvents.Testing do
  @moduledoc """
  Test helpers for asserting on emitted events.

  This module complements `Oban.Testing` with helpers that understand the
  `ObanEvents.DispatchWorker` job shape (event, handler, data, metadata),
  so tests don't need to hand-roll `assert_enqueued`/`refute_enqueued`
  matchers.

  ## Usage

      defmodule MyApp.AccountsTest do
        use ExUnit.Case, async: true

        use Oban.Testing, repo: MyApp.Repo
        import ObanEvents.Testing

        test "emits user_created" do
          {:ok, user} = MyApp.Accounts.create_user(%{email: "a@b.com"})

          assert_event_emitted(:user_created, %{"user_id" => user.id})
        end
      end

  `use Oban.Testing` must be configured in the test module (or its case
  template) since these helpers delegate to `Oban.Testing.assert_enqueued/2`
  and `Oban.Testing.refute_enqueued/2` under the hood.
  """

  alias Oban.Testing

  @doc """
  Assert that an event was emitted (i.e. an `ObanEvents.DispatchWorker` job
  was enqueued for it).

  ## Options

  All options accepted by `Oban.Testing.assert_enqueued/2` are supported
  (e.g. `:queue`, `:prefix`). Additionally:

  - `:handler` - Restrict the assertion to jobs for a specific handler
    module.

  ## Examples

      assert_event_emitted(:user_created)
      assert_event_emitted(:user_created, %{"user_id" => 1})
      assert_event_emitted(:user_created, %{"user_id" => 1}, handler: MyApp.EmailHandler)
  """
  defmacro assert_event_emitted(event_name, data \\ nil, opts \\ []) do
    quote bind_quoted: [event_name: event_name, data: data, opts: opts] do
      ObanEvents.Testing.__assert_event_emitted__(event_name, data, opts)
    end
  end

  @doc """
  Refute that an event was emitted. See `assert_event_emitted/3` for
  supported options.
  """
  defmacro refute_event_emitted(event_name, data \\ nil, opts \\ []) do
    quote bind_quoted: [event_name: event_name, data: data, opts: opts] do
      ObanEvents.Testing.__refute_event_emitted__(event_name, data, opts)
    end
  end

  @doc false
  def __assert_event_emitted__(event_name, data, opts) do
    args = build_args(event_name, data, opts)
    enqueued_opts = build_enqueued_opts(args, opts)

    Testing.assert_enqueued(
      [worker: ObanEvents.DispatchWorker, args: args] ++ enqueued_opts
    )
  end

  @doc false
  def __refute_event_emitted__(event_name, data, opts) do
    args = build_args(event_name, data, opts)
    enqueued_opts = build_enqueued_opts(args, opts)

    Testing.refute_enqueued(
      [worker: ObanEvents.DispatchWorker, args: args] ++ enqueued_opts
    )
  end

  defp build_args(event_name, data, opts) do
    %{}
    |> Map.put("event", Atom.to_string(event_name))
    |> maybe_put("data", data)
    |> maybe_put("handler", opts |> Keyword.get(:handler) |> handler_to_string())
  end

  defp handler_to_string(nil), do: nil
  defp handler_to_string(handler), do: Atom.to_string(handler)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp build_enqueued_opts(_args, opts) do
    opts
    |> Keyword.drop([:handler])
  end

  @doc """
  Build event job args for use with `Oban.Testing` matchers directly, when
  the `assert_event_emitted/3` / `refute_event_emitted/3` helpers aren't a
  good fit.

  ## Examples

      assert_enqueued(worker: ObanEvents.DispatchWorker, args: event_args(:user_created))
  """
  @spec event_args(atom(), map() | nil, module() | nil) :: map()
  def event_args(event_name, data \\ nil, handler \\ nil) when is_atom(event_name) do
    build_args(event_name, data, handler: handler)
  end
end
