defmodule ObanChore.Test.MockRepo do
  @moduledoc false

  # Stands in for an Ecto repo so ObanChore's queries can run without a database.
  #
  # Results are stubbed per test process with `stub/2`, either as a static value or as a
  # one-arity function that receives the query. Stubs live in the process dictionary, so
  # they only apply to queries issued from the test process itself.

  def stub(callback, result), do: Process.put({__MODULE__, callback}, result)

  @doc "Returns the worker name a query produced by ObanChore filters on."
  def worker_filter(%Ecto.Query{wheres: wheres}) do
    wheres
    |> Enum.flat_map(& &1.params)
    |> Enum.find_value(fn
      {worker, _type} when is_binary(worker) -> worker
      _ -> nil
    end)
  end

  def aggregate(query, :count, :id), do: respond(:aggregate, query, 0)
  def exists?(query), do: respond(:exists?, query, false)
  def all(query), do: respond(:all, query, [])

  # Oban verifies the migrated schema version when it starts in a testing mode.
  def query(_sql, _params, _opts) do
    {:ok, %{rows: [[to_string(Oban.Migrations.Postgres.current_version())]]}}
  end

  def __adapter__, do: Ecto.Adapters.Postgres
  def config, do: [priv: "priv", otp_app: :oban_chore]

  defp respond(callback, query, default) do
    case Process.get({__MODULE__, callback}, default) do
      fun when is_function(fun, 1) -> fun.(query)
      result -> result
    end
  end
end
