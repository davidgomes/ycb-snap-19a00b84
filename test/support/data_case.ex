defmodule Warehouse.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Ecto.Query
      import Mox, only: [set_mox_from_context: 1]
      import Warehouse.DataCase
      import Warehouse.Factory

      alias Ecto.Changeset
      alias Warehouse.Repo

      @moduletag capture_log: true

      setup :set_mox_from_context
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Warehouse.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Warehouse.Repo, {:shared, self()})
    end

    on_exit(fn ->
      Warehouse.ComponentSupervisor
      |> DynamicSupervisor.which_children()
      |> Enum.map(fn {_, pid, _, _} -> pid end)
      |> Enum.map(fn pid -> DynamicSupervisor.terminate_child(Warehouse.ComponentSupervisor, pid) end)

      Warehouse.SkuSupervisor
      |> DynamicSupervisor.which_children()
      |> Enum.map(fn {_, pid, _, _} -> pid end)
      |> Enum.map(fn pid -> DynamicSupervisor.terminate_child(Warehouse.SkuSupervisor, pid) end)
    end)

    :ok
  end

  @doc """
  Retries an assertion until it passes or the timeout (in ms) runs out. Used
  for state that is updated by asynchronous tasks.
  """
  def assert_eventually(fun, timeout \\ 1_000) do
    fun.()
  rescue
    error in [ExUnit.AssertionError] ->
      if timeout > 0 do
        Process.sleep(10)
        assert_eventually(fun, timeout - 10)
      else
        reraise error, __STACKTRACE__
      end
  end
end
