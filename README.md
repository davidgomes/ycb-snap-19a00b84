# Oban.Notifiers.Phoenix

[![CI](https://github.com/sorentwo/oban_notifiers_phoenix/actions/workflows/ci.yml/badge.svg)](https://github.com/sorentwo/oban_notifiers_phoenix/actions)
[![Hex Version](https://img.shields.io/hexpm/v/oban_notifiers_phoenix.svg)](https://hex.pm/packages/oban_notifiers_phoenix)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/oban_notifiers_phoenix/)
[![Apache 2 License](https://img.shields.io/hexpm/l/oban_notifiers_phoenix)](https://opensource.org/licenses/Apache-2.0)

An [Oban.Notifier][notifier] that uses [Phoenix.PubSub][pubsub] for notifications.

The Phoenix notifier allows Oban to share a Phoenix application's PubSub for notifications. In
addition to centralizing PubSub communications, it opens up the possible transports to all PubSub
adapters. It also avoids Postgres `LISTEN/NOTIFY`, making it compatible with connection poolers
such as PgBouncer in transaction mode.

## Installation

Add `:oban_notifiers_phoenix` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:oban_notifiers_phoenix, "~> 0.1"}
  ]
end
```

## Usage

Configure Oban to use the notifier with your application's PubSub name:

```elixir
config :my_app, Oban,
  notifier: {Oban.Notifiers.Phoenix, pubsub: MyApp.PubSub},
  ...
```

See the [documentation][docs] for full details.

## Contributing

Run the test suite with `mix test`, and check formatting with `mix format --check-formatted`.

## License

Copyright 2023 Parker Selbert. Released under the Apache License, Version 2.0; see
[LICENSE](LICENSE.txt).

[notifier]: https://hexdocs.pm/oban/Oban.Notifier.html
[pubsub]: https://hexdocs.pm/phoenix_pubsub
[docs]: https://hexdocs.pm/oban_notifiers_phoenix
