# BadgeForge

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Python worker

Badge generation jobs are enqueued from Elixir (`BadgeForge.generate_badge/2`)
but processed by a Python worker in `python/`, using the
[`oban`](https://pypi.org/project/oban/) Python package, which is fully
compatible with Elixir's Oban and shares the same `oban_jobs` table.

To run it locally (requires [`uv`](https://docs.astral.sh/uv/)):

```
cd python
uv sync
uv run oban start --config oban.toml
```

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
