# Oban.Notifiers.Phoenix

[![Hex Version](https://img.shields.io/hexpm/v/oban_notifiers_phoenix.svg)](https://hex.pm/packages/oban_notifiers_phoenix)
[![Hex Docs](https://img.shields.io/badge/hex.pm-docs-green.svg?style=flat)](https://hexdocs.pm/oban_notifiers_phoenix)
[![CI Status](https://github.com/sorentwo/oban_notifiers_phoenix/workflows/ci/badge.svg)](https://github.com/sorentwo/oban_notifiers_phoenix/actions)
[![Apache 2 License](https://img.shields.io/hexpm/l/oban_notifiers_phoenix)](https://opensource.org/licenses/Apache-2.0)

An [Oban][oban] notifier that uses [Phoenix.PubSub][pubsub] for notifications.

Oban uses a notifier to relay messages between nodes, e.g. to announce newly inserted jobs or to
signal queues to pause, resume, or scale. `Oban.Notifiers.Phoenix` shares your application's
existing PubSub for those notifications. In addition to centralizing PubSub communication, it
opens up the possible transports to every PubSub adapter. Oban already provides `Postgres` and
`PG` (Distributed Erlang) notifiers, so this package primarily enables notifications over Redis.

[oban]: https://github.com/sorentwo/oban
[pubsub]: https://github.com/phoenixframework/phoenix_pubsub

## Installation

Add `:oban_notifiers_phoenix` to your application's deps in `mix.exs`:

```elixir
def deps do
  [
    {:phoenix_pubsub, "~> 2.0"},
    {:oban_notifiers_phoenix, "~> 0.1"}
  ]
end
```

`Oban.Notifiers.Phoenix` requires Oban v2.17 or later.

## Usage

Make note of your application's `Phoenix.PubSub` instance name from the primary supervision tree:

```elixir
def start(_type, _args) do
  children = [
    {Phoenix.PubSub, name: MyApp.PubSub},
    ...
```

Then configure Oban to use `Oban.Notifiers.Phoenix` as the notifier, with the `PubSub` instance
name as the `:pubsub` option:

```elixir
config :my_app, Oban,
  notifier: {Oban.Notifiers.Phoenix, pubsub: MyApp.PubSub},
  ...
```

See the [documentation][docs] for more details.

[docs]: https://hexdocs.pm/oban_notifiers_phoenix

## Contributing

To run the test suite, fetch dependencies and run `mix test`:

```bash
mix deps.get
mix test
```

The tests don't require a database.

## License

Oban.Notifiers.Phoenix is released under the Apache License 2.0. See [LICENSE.txt](LICENSE.txt)
for details.
