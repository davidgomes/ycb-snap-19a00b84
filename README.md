# Oban.Notifiers.Phoenix

[![CI](https://github.com/sorentwo/oban_notifiers_phoenix/actions/workflows/ci.yml/badge.svg)](https://github.com/sorentwo/oban_notifiers_phoenix/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/oban_notifiers_phoenix.svg)](https://hex.pm/packages/oban_notifiers_phoenix)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/oban_notifiers_phoenix)
[![License](https://img.shields.io/hexpm/l/oban_notifiers_phoenix.svg)](https://github.com/sorentwo/oban_notifiers_phoenix/blob/main/LICENSE)

An `Oban.Notifier` that piggybacks on an application's `Phoenix.PubSub` for notifications,
letting Oban's PubSub-based features (queue control, insert notifications, etc.) work without
requiring a database-specific notification mechanism such as Postgres' `LISTEN/NOTIFY`.

## Installation

The package can be installed by adding `oban_notifiers_phoenix` to your list of dependencies in
`mix.exs`:

```elixir
def deps do
  [
    {:oban_notifiers_phoenix, "~> 0.1.0"}
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

Then configure Oban to use `Oban.Notifiers.Phoenix` as the notifier with the `PubSub` instance
name as the `:pubsub` option:

```elixir
config :my_app, Oban,
  notifier: {Oban.Notifiers.Phoenix, pubsub: MyApp.PubSub},
  ...
```

## Documentation

Documentation is generated with [ExDoc](https://github.com/elixir-lang/ex_doc) and published on
[HexDocs](https://hexdocs.pm/oban_notifiers_phoenix).

## Contributing

Issues and pull requests are welcome. Run the test suite with `mix test` and ensure code is
formatted with `mix format` before submitting changes.

## License

`Oban.Notifiers.Phoenix` is released under the [MIT License](./LICENSE).
