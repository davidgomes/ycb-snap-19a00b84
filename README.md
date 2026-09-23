# Oban.Notifiers.Phoenix

[![CI](https://github.com/oban-bg/oban_notifiers_phoenix/actions/workflows/ci.yml/badge.svg)](https://github.com/oban-bg/oban_notifiers_phoenix/actions/workflows/ci.yml)
[![Hex Version](https://img.shields.io/hexpm/v/oban_notifiers_phoenix.svg)](https://hex.pm/packages/oban_notifiers_phoenix)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/oban_notifiers_phoenix/)
[![Apache 2 License](https://img.shields.io/hexpm/l/oban_notifiers_phoenix)](https://opensource.org/licenses/Apache-2.0)

An [Oban.Notifier][notifier] that piggybacks on an application's [Phoenix.PubSub][pubsub] for
notifications.

Notifications are broadcast through whichever adapter your `PubSub` instance uses, so there's no
dependency on Postgres `LISTEN/NOTIFY`. That makes it a good fit for applications that already run
`Phoenix.PubSub`, or that connect to the database through a transaction pooler such as PgBouncer.

[notifier]: https://hexdocs.pm/oban/Oban.Notifier.html
[pubsub]: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html

## Installation

Add `:oban_notifiers_phoenix` to your application's deps, along with `:phoenix_pubsub`:

```elixir
def deps do
  [
    {:phoenix_pubsub, "~> 2.0"},
    {:oban_notifiers_phoenix, "~> 0.1"}
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

Then configure Oban to use `Oban.Notifiers.Phoenix` as the notifier with the `PubSub` instance
name as the `:pubsub` option:

```elixir
config :my_app, Oban,
  notifier: {Oban.Notifiers.Phoenix, pubsub: MyApp.PubSub},
  ...
```

Full documentation is available on [HexDocs][docs].

[docs]: https://hexdocs.pm/oban_notifiers_phoenix

## Contributing

To run the test suite, fetch dependencies and run `mix test`:

```bash
mix deps.get
mix test
```

## License

Copyright 2023 Parker Selbert

Oban.Notifiers.Phoenix is released under the Apache License, Version 2.0. See
[LICENSE.txt](LICENSE.txt) for details.
