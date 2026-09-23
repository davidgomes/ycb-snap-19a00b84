# InnoDB gap locks make concurrent sandboxed tests deadlock on MySQL
case EctoJob.Test.Repo.__adapter__() do
  Ecto.Adapters.Postgres -> ExUnit.start()
  _adapter -> ExUnit.start(max_cases: 1)
end

EctoJob.Test.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(EctoJob.Test.Repo, :manual)
