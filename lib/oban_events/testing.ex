defmodule ObanEvents.Testing do
  @moduledoc """
  Test helpers for applications built on `ObanEvents`.

  These helpers cut down on the boilerplate involved in asserting that an
  event was emitted, without needing to hand-build `ObanEvents.DispatchWorker`
  job args in every test.

  ## Usage

      defmodule MyApp.AccountsTest do
        use ExUnit.Case, async: true
        use Oban.Testing, repo: MyApp.Repo
        import ObanEvents.Testing

        test "creates a user and emits :user_created" do
          {:ok, user} = MyApp.Accounts.create_user(%{email: "test@example.com"})

          assert_event_emitted(:user_created, MyApp.EmailHandler, %{
            "user_id" => user.id
          })
        end
      end

  `assert_event_emitted/2` and `assert_event_emitted/3` are built on top of
  `Oban.Testing.assert_enqueued/1`, so the calling test case must also
  `use Oban.Testing, repo: ...`. Since `assert_enqueued/1` queries the
  database directly, your Oban instance must be configured for `:manual`
  testing mode (the default recommendation for testing with Oban) rather
  than `:inline` mode, which never persists jobs to be asserted on
  afterwards.
  """

  alias ObanEvents.DispatchWorker

  @doc """
  Build the `ObanEvents.DispatchWorker` job args that `emit/2` or `emit/3`
  would enqueue for the given event/handler/data combination.

  Useful for building fixtures for `Oban.Testing.assert_enqueued/1` and
  `Oban.Testing.perform_job/2`, or as a starting point for a custom match.
  Note that jobs emitted with additional metadata will also include
  `"metadata"`, `"event_id"`, and `"emitted_at"` keys; since job args are
  matched as a subset, this helper's map still matches those jobs.

  ## Examples

      iex> ObanEvents.Testing.event_args(:user_created, MyApp.EmailHandler, %{"user_id" => 1})
      %{"event" => "user_created", "handler" => "Elixir.MyApp.EmailHandler", "data" => %{"user_id" => 1}}
  """
  @spec event_args(atom(), module(), map()) :: map()
  def event_args(event_name, handler, data \\ %{})
      when is_atom(event_name) and is_atom(handler) and is_map(data) do
    %{
      "event" => Atom.to_string(event_name),
      "handler" => Atom.to_string(handler),
      "data" => data
    }
  end

  @doc """
  Assert that an `ObanEvents.DispatchWorker` job was enqueued for the given
  event and handler.

  See `assert_event_emitted/3` to also match on the event's `data`.

  ## Examples

      assert_event_emitted(:user_created, MyApp.EmailHandler)
  """
  defmacro assert_event_emitted(event_name, handler) do
    quote do
      assert_event_emitted(unquote(event_name), unquote(handler), %{})
    end
  end

  @doc """
  Assert that an `ObanEvents.DispatchWorker` job was enqueued for the given
  event and handler, matching on `data`.

  Requires the calling test case to `use Oban.Testing, repo: ...`.

  ## Examples

      assert_event_emitted(:user_created, MyApp.EmailHandler, %{"user_id" => user.id})
  """
  defmacro assert_event_emitted(event_name, handler, data) do
    quote do
      assert_enqueued(
        worker: DispatchWorker,
        args: ObanEvents.Testing.event_args(unquote(event_name), unquote(handler), unquote(data))
      )
    end
  end
end
