ExUnit.start()

# Each sandboxed test holds an open transaction, and InnoDB locks every row scanned by an
# UPDATE, so concurrent tests would deadlock on each other's rows with MySQL.
if EctoJob.Test.Repo.__adapter__() == Ecto.Adapters.MyXQL do
  ExUnit.configure(max_cases: 1)
end

EctoJob.Test.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(EctoJob.Test.Repo, :manual)
