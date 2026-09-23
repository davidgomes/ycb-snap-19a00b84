# Concurrent sandbox transactions updating the same table deadlock under InnoDB locking
exunit_opts =
  if EctoJob.Test.Repo.__adapter__() == Ecto.Adapters.MyXQL, do: [max_cases: 1], else: []

ExUnit.start(exunit_opts)

EctoJob.Test.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(EctoJob.Test.Repo, :manual)
