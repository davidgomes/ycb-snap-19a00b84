defmodule ObanChore.Test.MockRepo do
  @moduledoc false

  # A stand-in for an Ecto repo so Oban can boot and ObanChore's queries can run
  # without a database. Every query is sent back to the calling process, and
  # results are read from that process's dictionary, so stubs set with `stub/2`
  # only apply to the test that set them. A stub may be a one-arity function,
  # which is called with the query.

  def stub(function, result), do: Process.put({__MODULE__, function}, result)

  def aggregate(query, :count, :id) do
    send(self(), {:repo_aggregate, query})
    result(:aggregate, query, 0)
  end

  def exists?(query) do
    send(self(), {:repo_exists, query})
    result(:exists?, query, false)
  end

  def all(query) do
    send(self(), {:repo_all, query})
    result(:all, query, [])
  end

  # Oban reads the migrated version of `oban_jobs` before booting in a testing
  # mode, so always report the table as fully migrated.
  def query(_sql, _params, _opts) do
    version = Oban.Migration.current_version(repo: __MODULE__)
    {:ok, %{rows: [[Integer.to_string(version)]]}}
  end

  def __adapter__, do: Ecto.Adapters.Postgres

  def config, do: [priv: "priv", otp_app: :oban_chore]

  defp result(function, query, default) do
    case Process.get({__MODULE__, function}, default) do
      stub when is_function(stub, 1) -> stub.(query)
      result -> result
    end
  end
end
