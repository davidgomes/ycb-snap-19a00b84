if EctoJob.Test.Repo.__adapter__() == Ecto.Adapters.MyXQL do
  # InnoDB row locking makes concurrent sandboxed updates of the jobs table deadlock-prone
  ExUnit.start(max_cases: 1)
else
  ExUnit.start()
end

EctoJob.Test.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(EctoJob.Test.Repo, :manual)
