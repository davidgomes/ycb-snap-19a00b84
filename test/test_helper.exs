# InnoDB blocks on rows inserted by other uncommitted sandbox transactions, so
# concurrent test cases deadlock on MySQL.
case EctoJob.Test.Repo.__adapter__() do
  Ecto.Adapters.MyXQL -> ExUnit.start(max_cases: 1)
  _ -> ExUnit.start()
end

EctoJob.Test.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(EctoJob.Test.Repo, :manual)
