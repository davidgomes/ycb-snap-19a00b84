# Oban.Notifiers.Phoenix

[![CI](https://github.com/sorentwo/oban_notifiers_phoenix/actions/workflows/ci.yml/badge.svg)](https://github.com/sorentwo/oban_notifiers_phoenix/actions)
[![Hex Version](https://img.shields.io/hexpm/v/oban_notifiers_phoenix.svg)](https://hex.pm/packages/oban_notifiers_phoenix)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/oban_notifiers_phoenix/)
[![Apache 2 License](https://img.shields.io/hexpm/l/oban_notifiers_phoenix)](https://opensource.org/licenses/Apache-2.0)

An [Oban][oban] notifier that uses [Phoenix.PubSub][pubsub] for notifications. It allows
Oban to share an application's existing PubSub for distributed notifications, rather than
relying on PostgreSQL `LISTEN/NOTIFY`.

## Installation

Add `oban_notifiers_phoenix` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:oban_notifiers_phoenix, "~> 0.1"}
  ]
end
```

## Usage

Configure Oban to use the notifier along with your application's PubSub name:

```elixir
config :my_app, Oban,
  notifier: {Oban.Notifiers.Phoenix, pubsub: MyApp.PubSub},
  ...
```

See the [documentation](https://hexdocs.pm/oban_notifiers_phoenix) for details.

## Contributing

Run the test suite with `mix test`, and check formatting with `mix format --check-formatted`.

## License

Copyright 2024 Parker Selbert. Released under the Apache License, Version 2.0. See
[LICENSE](LICENSE) for details.

[oban]: https://github.com/sorentwo/oban
[pubsub]: https://github.com/phoenixframework/phoenix_pubsub
