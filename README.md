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

An [Oban.Notifier][no] that uses [Phoenix.PubSub][pp] for notifications.

The Phoenix notifier lets Oban share an application's existing `Phoenix.PubSub` instance rather
than relying on a dedicated connection. That centralizes PubSub communication and opens Oban
notifications up to any PubSub adapter, e.g. Redis via [phoenix_pubsub_redis][pr].

[no]: https://hexdocs.pm/oban/Oban.Notifier.html
[pp]: https://hexdocs.pm/phoenix_pubsub
[pr]: https://hex.pm/packages/phoenix_pubsub_redis

## Installation

Add `:oban_notifiers_phoenix` to your application's deps in `mix.exs`:

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

To run the test suite, fetch dependencies and run the tests:

```bash
mix deps.get
mix test
```

Before submitting a pull request, ensure the code is formatted and compiles without warnings:

```bash
mix format --check-formatted
mix compile --warnings-as-errors
```

## License

Oban Notifiers Phoenix is released under the Apache 2.0 License. See [LICENSE.txt](LICENSE.txt)
for details.
