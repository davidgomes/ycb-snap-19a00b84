# BadgeForge

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Python badge worker

The Python worker and Elixir app use the same PostgreSQL-backed Oban queue. Set
up and start the worker in a second terminal:

```bash
cd python
python -m venv .venv
.venv/bin/pip install -e .
.venv/bin/oban start
```

Then enqueue jobs from Elixir:

```elixir
BadgeForge.enqueue_batch(10)
```

Elixir inserts `badge_forge.generator.GenerateBadge` jobs on the `badges`
queue. Python processes them and writes printable HTML to `python/badges/`.
Override the output directory with `BADGES_DIR`, or update `python/oban.toml`
when the worker and Phoenix app don't use the default development database.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
