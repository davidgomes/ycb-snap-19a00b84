# MySQL InnoDB deadlocks when async cases share one database through the sandbox.
if Application.get_env(:ecto_job, EctoJob.Test.Repo)[:adapter] == Ecto.Adapters.MyXQL do
  ExUnit.configure(max_cases: 1)
end

ExUnit.start()

EctoJob.Test.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(EctoJob.Test.Repo, :manual)
