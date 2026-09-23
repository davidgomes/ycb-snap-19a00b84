defmodule ObanChore.DataCase do
  @moduledoc """
  Test case for tests that need a real database and a running `Oban` instance.

  Each test runs inside an Ecto sandbox in shared mode, so these tests must not be async.
  """
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      use Oban.Testing, repo: ObanChore.TestRepo

      alias ObanChore.TestRepo
    end
  end

  @telemetry_handler {:oban_chore_counts, Oban}

  setup tags do
    # ObanChore.Plugin attaches this handler globally and never detaches it, so a handler left
    # behind by another test would broadcast to that test's (possibly stopped) PubSub.
    :telemetry.detach(@telemetry_handler)
    on_exit(fn -> :telemetry.detach(@telemetry_handler) end)

    pid = Sandbox.start_owner!(ObanChore.TestRepo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    start_supervised!({Oban, name: Oban, repo: ObanChore.TestRepo, testing: :manual})

    :ok
  end
end
