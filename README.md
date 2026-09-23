# Oban Notifiers Phoenix

<p align="center">
  <a href="https://hex.pm/packages/oban_notifiers_phoenix">
    <img alt="Hex Version" src="https://img.shields.io/hexpm/v/oban_notifiers_phoenix.svg">
  </a>

  <a href="https://hexdocs.pm/oban_notifiers_phoenix">
    <img alt="Hex Docs" src="http://img.shields.io/badge/hex.pm-docs-green.svg?style=flat">
  </a>

  <a href="https://github.com/sorentwo/oban_notifiers_phoenix/actions">
    <img alt="CI Status" src="https://github.com/sorentwo/oban_notifiers_phoenix/workflows/ci/badge.svg">
  </a>

  <a href="https://opensource.org/licenses/Apache-2.0">
    <img alt="Apache 2 License" src="https://img.shields.io/hexpm/l/oban_notifiers_phoenix">
  </a>
</p>

An [Oban.Notifier][no] that piggybacks on an application's [Phoenix.PubSub][pp] for
notifications.

Using `Phoenix.PubSub` for notifications is an alternative to the default Postgres notifier,
which relies on `LISTEN/NOTIFY`. It doesn't require a database connection for notifications,
works with databases that don't support `LISTEN/NOTIFY`, and works with connection poolers such
as PgBouncer in transaction mode. Notifications are only delivered between nodes that are
connected in the same cluster.

[no]: https://hexdocs.pm/oban/Oban.Notifier.html
[pp]: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html

## Installation

Add `:oban_notifiers_phoenix` to your application's deps, along with `:phoenix_pubsub` if it
isn't already a dependency:

```elixir
def deps do
  [
    {:oban_notifiers_phoenix, "~> 0.1"},
    {:phoenix_pubsub, "~> 2.0"}
  ]
end
```

## Usage

Make note of your application's `Phoenix.PubSub` instance name from the primary supervision tree:

```elixir
def start(_type, _args) do
  children = [
    {Phoenix.PubSub, name: MyApp.PubSub},
    ...
```

Then configure Oban to use `Oban.Notifiers.Phoenix` as the notifier, passing the `PubSub`
instance name as the `:pubsub` option:

```elixir
config :my_app, Oban,
  notifier: {Oban.Notifiers.Phoenix, pubsub: MyApp.PubSub},
  ...
```

## Contributing

To run the test suite you must have Elixir and Erlang installed. Fetch dependencies and run the
tests:

```bash
mix deps.get
mix test
```

To generate the documentation locally:

```bash
mix docs
```

## License

Copyright 2023 Parker Selbert

Licensed under the Apache License, Version 2.0. See [LICENSE.txt](LICENSE.txt) for details.
