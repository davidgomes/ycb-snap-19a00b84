{:ok, _} = Application.ensure_all_started(:ex_machina)

ExUnit.start()

Mimic.copy(Oban)
Mimic.copy(Oban.Repo)
Mimic.copy(Oban.Console.Repo)
