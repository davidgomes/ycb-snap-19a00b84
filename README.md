# Oban Notifiers Phoenix

[![CI](https://github.com/sorentwo/oban_notifiers_phoenix/actions/workflows/ci.yml/badge.svg)](https://github.com/sorentwo/oban_notifiers_phoenix/actions/workflows/ci.yml)
[![Hex Version](https://img.shields.io/hexpm/v/oban_notifiers_phoenix.svg)](https://hex.pm/packages/oban_notifiers_phoenix)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/oban_notifiers_phoenix/)
[![Apache 2 License](https://img.shields.io/hexpm/l/oban_notifiers_phoenix)](https://opensource.org/licenses/Apache-2.0)

An [Oban.Notifier][notifier] that piggybacks on an application's existing `Phoenix.PubSub` for
notifications, rather than relying on Postgres `LISTEN/NOTIFY`.

## Installation

Add `:oban_notifiers_phoenix` to your application's deps:

```elixir
def deps do
  [
    {:oban_notifiers_phoenix, "~> 0.1"}
  ]
end
```

## Usage

Configure Oban to use `Oban.Notifiers.Phoenix` with your application's `Phoenix.PubSub` instance
name as the `:pubsub` option:

```elixir
config :my_app, Oban,
  notifier: {Oban.Notifiers.Phoenix, pubsub: MyApp.PubSub},
  ...
```

See the [documentation][docs] for full details.

## Contributing

Run the test suite with `mix test`. Tests require a running Postgres database.

## License

Copyright 2023 Parker Selbert. Released under the Apache License, Version 2.0. See
[LICENSE.txt](LICENSE.txt) for details.

[notifier]: https://hexdocs.pm/oban/Oban.Notifier.html
[docs]: https://hexdocs.pm/oban_notifiers_phoenix
