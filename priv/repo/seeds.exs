# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     FreeObanUi.Repo.insert!(%FreeObanUi.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias FreeObanUi.Workers.ExampleWorker

for i <- 1..20 do
  %{index: i, sleep: Enum.random(500..5_000), fail: rem(i, 5) == 0}
  |> ExampleWorker.new(schedule_in: Enum.random(0..60))
  |> Oban.insert!()
end
