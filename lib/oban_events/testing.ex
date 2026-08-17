defmodule ObanEvents.Testing do
  @moduledoc """
  Testing helpers for asserting on events emitted through `ObanEvents`.

  These helpers wrap `Oban.Testing`'s job assertions with knowledge of how
  `ObanEvents.DispatchWorker` job args are structured, so tests can assert on
  event names and data without reaching into Oban job internals.

  ## Usage

  Add `use ObanEvents.Testing, repo: MyApp.Repo` to your test module (this
  also configures `Oban.Testing` for you, so there's no need to `use
  Oban.Testing` separately):

      defmodule MyApp.AccountsTest do
        use ExUnit.Case, async: true
        use ObanEvents.Testing, repo: MyApp.Repo

        test "emits user_created event" do
          {:ok, _user} = Accounts.create_user(%{email: "test@example.com"})

          assert_event_emitted(:user_created, %{"email" => "test@example.com"})
        end

        test "does not emit user_created event when signup fails" do
          Accounts.create_user(%{email: "invalid"})

          refute_event_emitted(:user_created)
        end
      end

  `data` is matched as a subset: only the keys you provide are checked
  against the enqueued job's data, so you don't need to list every field.
  Pass `handler:` in `opts` to further scope the assertion to a specific
  handler module.
  """

  @doc false
  defmacro __using__(opts) do
    quote do
      use Oban.Testing, unquote(opts)

      @doc """
      Assert that an event matching `event_name` (and, optionally, `data`)
      was enqueued as an `ObanEvents.DispatchWorker` job.

      `data` may be a partial map: only the given keys are checked against
      the job's data. `assert_opts` accepts a `:handler` module to scope the
      assertion, plus any option supported by `Oban.Testing.assert_enqueued/1`
      (e.g. `:queue`).
      """
      @spec assert_event_emitted(atom(), map(), keyword()) :: true
      def assert_event_emitted(event_name, data \\ %{}, assert_opts \\ [])
          when is_atom(event_name) and is_map(data) and is_list(assert_opts) do
        assert_opts
        |> ObanEvents.Testing.build_enqueued_opts(event_name, data)
        |> assert_enqueued()
      end

      @doc """
      Refute that an event matching `event_name` (and, optionally, `data`)
      was enqueued as an `ObanEvents.DispatchWorker` job.

      See `assert_event_emitted/3` for details on `data` and `assert_opts`.
      """
      @spec refute_event_emitted(atom(), map(), keyword()) :: false
      def refute_event_emitted(event_name, data \\ %{}, assert_opts \\ [])
          when is_atom(event_name) and is_map(data) and is_list(assert_opts) do
        assert_opts
        |> ObanEvents.Testing.build_enqueued_opts(event_name, data)
        |> refute_enqueued()
      end
    end
  end

  @doc false
  @spec build_enqueued_opts(keyword(), atom(), map()) :: keyword()
  def build_enqueued_opts(opts, event_name, data) do
    args =
      %{"event" => Atom.to_string(event_name), "data" => data}
      |> put_handler(Keyword.get(opts, :handler))

    opts
    |> Keyword.delete(:handler)
    |> Keyword.put(:worker, ObanEvents.DispatchWorker)
    |> Keyword.put(:args, args)
  end

  defp put_handler(args, nil), do: args
  defp put_handler(args, handler), do: Map.put(args, "handler", Atom.to_string(handler))
end
