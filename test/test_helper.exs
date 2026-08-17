Application.ensure_all_started(:mimic)
Mimic.copy(Oban)

ExUnit.start()
