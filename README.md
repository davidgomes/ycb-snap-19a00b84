# Oban Notifiers Phoenix

<p align="center">
  <a href="https://hex.pm/packages/oban_notifiers_phoenix">
    <img alt="Hex Version" src="https://img.shields.io/hexpm/v/oban_notifiers_phoenix.svg">
  </a>

  <a href="https://hexdocs.pm/oban_notifiers_phoenix">
    <img alt="Hex Docs" src="http://img.shields.io/badge/hex.pm-docs-green.svg?style=flat">
  </a>

  <a href="https://github.com/sorentwo/oban_notifiers_phoenix/actions">
    <img alt="CI Status" src="https://github.com/sorentwo/oban_notifiers_phoenix/workflows/CI/badge.svg">
  </a>

  <a href="https://opensource.org/licenses/Apache-2.0">
    <img alt="Apache 2 License" src="https://img.shields.io/hexpm/l/oban_notifiers_phoenix">
  </a>
</p>

An [Oban][oba] notifier that piggybacks on an application's [Phoenix.PubSub][pps] for
notifications.

Oban's default notifier relies on Postgres `LISTEN/NOTIFY`, which isn't available in every
environment (e.g. behind PgBouncer in transaction mode) and adds load to the database. This
notifier uses your application's existing `Phoenix.PubSub` instance instead, which is ideal for
clustered applications that already run a distributed PubSub.

[oba]: https://github.com/sorentwo/oban
[pps]: https://github.com/phoenixframework/phoenix_pubsub

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

Make note of your application's `Phoenix.PubSub` instance name from the primary supervision
tree:

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

Notifications are only delivered between nodes that share the same `Phoenix.PubSub` instance, so
make sure your nodes are clustered (for example with [libcluster][lib] or [dns_cluster][dns]).

[lib]: https://github.com/bitwalker/libcluster
[dns]: https://github.com/phoenixframework/dns_cluster

## Documentation

Full documentation is available on [HexDocs][hd]. To build the docs locally, run
`mix docs`.

[hd]: https://hexdocs.pm/oban_notifiers_phoenix

## Contributing

To run the full CI suite locally (formatting, unused dependency check, compilation warnings,
Credo, and tests):

```bash
mix test.ci
```

## License

Copyright 2023 Parker Selbert

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
in compliance with the License. You may obtain a copy of the License at
[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software distributed under the
License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
either express or implied. See the License for the specific language governing permissions and
limitations under the License.
