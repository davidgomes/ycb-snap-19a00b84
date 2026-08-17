ExUnit.start()

# Start the test repo for plugin tests
{:ok, _} = ObanDoctor.Test.Repo.start_link()

# Run Oban migrations
Ecto.Migrator.up(ObanDoctor.Test.Repo, 0, Oban.Migration)

# Set sandbox mode for async tests
Ecto.Adapters.SQL.Sandbox.mode(ObanDoctor.Test.Repo, :manual)

# Start Oban for plugin tests
# Use Global peer instead of Database peer to avoid sandbox conflicts
{:ok, _} =
  Oban.start_link(
    name: ObanDoctor.TestOban,
    repo: ObanDoctor.Test.Repo,
    queues: [default: 10, mailers: 5],
    peer: Oban.Peers.Global
  )
