# Oban Notifiers Phoenix

[![CI](https://github.com/sorentwo/oban_notifiers_phoenix/actions/workflows/ci.yml/badge.svg)](https://github.com/sorentwo/oban_notifiers_phoenix/actions/workflows/ci.yml)
[![Hex Version](https://img.shields.io/hexpm/v/oban_notifiers_phoenix.svg)](https://hex.pm/packages/oban_notifiers_phoenix)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/oban_notifiers_phoenix/)
[![Apache 2 License](https://img.shields.io/hexpm/l/oban_notifiers_phoenix)](https://opensource.org/licenses/Apache-2.0)

An [Oban][oban] notifier that piggybacks on an application's [Phoenix.PubSub][pubsub] for
notifications.

Notifications are broadcast through `Phoenix.PubSub` rather than the database, so they reach
every node that shares the same `PubSub` instance, whichever adapter it's configured with.

[oban]: https://github.com/sorentwo/oban
[pubsub]: https://github.com/phoenixframework/phoenix_pubsub

## Installation

Add `:oban_notifiers_phoenix` to your application's deps, alongside `:phoenix_pubsub`:

```elixir
def deps do
  [
    {:phoenix_pubsub, "~> 2.0"},
    {:oban_notifiers_phoenix, "~> 0.1"}
  ]
end
```

## Usage

Make note of your application's `Phoenix.PubSub` instance name from the primary supervision
tree:

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

Full documentation is available on [HexDocs][docs].

[docs]: https://hexdocs.pm/oban_notifiers_phoenix

## License

Oban Notifiers Phoenix is released under the Apache License 2.0. See [LICENSE.txt](LICENSE.txt)
for details.
