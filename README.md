# Oban.Notifiers.Phoenix

[![CI](https://github.com/oban-bg/oban_notifiers_phoenix/actions/workflows/ci.yml/badge.svg)](https://github.com/oban-bg/oban_notifiers_phoenix/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/oban_notifiers_phoenix.svg)](https://hex.pm/packages/oban_notifiers_phoenix)
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/oban_notifiers_phoenix)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](./LICENSE.txt)

An [Oban.Notifier][no] that uses [Phoenix.PubSub][pp] for notifications.

The `Phoenix` notifier allows Oban to share a Phoenix application's `PubSub` for notifications. In
addition to centralizing PubSub communications, it opens up the possible transports to all PubSub
adapters.

Most importantly, as Oban already provides `Postgres` and `PG` notifiers, this package enables
Redis notifications via the [Phoenix.PubSub.Redis][pr] adapter.

[no]: https://hexdocs.pm/oban/Oban.Notifier.html
[pp]: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html
[pr]: https://hex.pm/packages/phoenix_pubsub_redis

## Installation

The package can be installed by adding `oban_notifiers_phoenix` to your list of dependencies in
`mix.exs`:

```elixir
defp deps do
  [
    {:oban_notifiers_phoenix, "~> 0.1"},
    ...
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

Finally, configure Oban to use `Oban.Notifiers.Phoenix` as the notifier with the `PubSub`
instance name as the `:pubsub` option:

```elixir
config :my_app, Oban,
  notifier: {Oban.Notifiers.Phoenix, pubsub: MyApp.PubSub},
  ...
```

## Documentation

Documentation is published on [HexDocs](https://hexdocs.pm) and can be found at
<https://hexdocs.pm/oban_notifiers_phoenix>.

## Contributing

Run `mix test.ci` locally to ensure changes will pass in CI. That alias executes the following
commands:

* Check formatting (`mix format --check-formatted`)
* Check unused deps (`mix deps.unlock --check-unused`)
* Lint with Credo (`mix credo --strict`)
* Run all tests (`mix test --raise`)
