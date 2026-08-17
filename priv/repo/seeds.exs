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

for i <- 1..5 do
  %{id: i, action: "process_item"}
  |> ExampleWorker.new(queue: :default)
  |> Oban.insert!()
end

for i <- 1..3 do
  %{id: i, recipient: "user#{i}@example.com"}
  |> ExampleWorker.new(queue: :mailers)
  |> Oban.insert!()
end

