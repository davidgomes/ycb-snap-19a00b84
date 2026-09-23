# Oban.Notifiers.Phoenix

[![CI](https://github.com/sorentwo/oban_notifiers_phoenix/actions/workflows/ci.yml/badge.svg)](https://github.com/sorentwo/oban_notifiers_phoenix/actions/workflows/ci.yml)
[![Hex Version](https://img.shields.io/hexpm/v/oban_notifiers_phoenix.svg)](https://hex.pm/packages/oban_notifiers_phoenix)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/oban_notifiers_phoenix/)
[![Apache 2 License](https://img.shields.io/hexpm/l/oban_notifiers_phoenix)](https://opensource.org/licenses/Apache-2.0)

An [Oban.Notifier][notifier] that piggybacks on an application's existing
[Phoenix.PubSub][pubsub] instance for notifications.

Using `Phoenix.PubSub` for notifications allows Oban to work without a PostgreSQL connection for
`LISTEN/NOTIFY`, and reuses the PubSub adapter (PG, Redis, etc.) that your application already
runs.

[notifier]: https://hexdocs.pm/oban/Oban.Notifier.html
[pubsub]: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html

## Installation

Add `:oban_notifiers_phoenix` to your list of deps in `mix.exs`:

```elixir
def deps do
  [
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

Then configure Oban to use `Oban.Notifiers.Phoenix` as the notifier, passing the `PubSub`
instance name as the `:pubsub` option:

```elixir
config :my_app, Oban,
  notifier: {Oban.Notifiers.Phoenix, pubsub: MyApp.PubSub},
  ...
```

## Contributing

To run the test suite and the same checks as CI:

```bash
mix deps.get
mix test.ci
```

## License

Copyright 2023 Parker Selbert

Licensed under the Apache License, Version 2.0. See [LICENSE.txt](LICENSE.txt) for details.
