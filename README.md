# BadgeForge

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Python workers

Badge generation runs in Python, in the `python/` directory. Both sides share
the same `oban_jobs` table, so enqueueing across languages is just an insert.

Install the workers and start them against the same database as the Elixir app:

```bash
cd python
pip install -e ".[dev]"
OBAN_DSN=postgresql://postgres:postgres@localhost/badge_forge_dev oban start
```

Then enqueue badges from Elixir:

```elixir
BadgeForge.Badges.enqueue_badges([%{name: "Ada Lovelace", company: "Analytical Engines"}])
```

The jobs land in the `badges` queue, which only Python listens on. Once a badge
is rendered to `priv/badges`, Python enqueues a `BadgeForge.PrintCenter` job on
the `printing` queue, which Elixir picks up.

Run the Python tests with `cd python && pytest`.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
