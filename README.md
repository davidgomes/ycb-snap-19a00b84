# Oban Notifiers Phoenix

[![CI](https://github.com/sorentwo/oban_notifiers_phoenix/actions/workflows/ci.yml/badge.svg)](https://github.com/sorentwo/oban_notifiers_phoenix/actions)
[![Hex Version](https://img.shields.io/hexpm/v/oban_notifiers_phoenix.svg)](https://hex.pm/packages/oban_notifiers_phoenix)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/oban_notifiers_phoenix/)
[![Apache 2 License](https://img.shields.io/hexpm/l/oban_notifiers_phoenix)](https://opensource.org/licenses/Apache-2.0)

An [Oban][oban] notifier that piggybacks on an application's [Phoenix.PubSub][pubsub] for
notifications.

Using `Phoenix.PubSub` for notifications allows Oban to exchange messages between nodes without a
Postgres connection, which makes it suitable for use with PgBouncer in transaction mode or with
databases that don't support `LISTEN/NOTIFY`.

[oban]: https://github.com/sorentwo/oban
[pubsub]: https://github.com/phoenixframework/phoenix_pubsub

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

Full documentation is available on [HexDocs][hexdocs].

[hexdocs]: https://hexdocs.pm/oban_notifiers_phoenix

## Contributing

To run the test suite and all quality checks:

```bash
mix deps.get
mix ci
```

## License

Copyright 2023 Parker Selbert

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
in compliance with the License. You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License
is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
or implied. See the License for the specific language governing permissions and limitations under
the License.
