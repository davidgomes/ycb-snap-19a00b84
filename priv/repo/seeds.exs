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

# Enqueue a handful of sample jobs so the Oban jobs dashboard (visit
# `/oban`) has some data to show right after setup.
alias FreeObanUi.Workers.ExampleWorker

for id <- 1..5 do
  %{id: id} |> ExampleWorker.new(queue: :default) |> Oban.insert!()
end

%{id: 6, fail: true} |> ExampleWorker.new(queue: :default) |> Oban.insert!()
%{id: 7} |> ExampleWorker.new(queue: :mailers, schedule_in: 300) |> Oban.insert!()
