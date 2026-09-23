ExUnit.start()

# The SQL sandbox does not support concurrent tests with MySQL
if EctoJob.Test.Repo.__adapter__() == Ecto.Adapters.MyXQL do
  ExUnit.configure(max_cases: 1)
end

EctoJob.Test.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(EctoJob.Test.Repo, :manual)
