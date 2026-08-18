# BadgeForge

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Python Oban worker

Badge generation jobs are enqueued from Elixir and processed by a Python
worker that shares the same `oban_jobs` table via
[Oban for Python](https://pypi.org/project/oban/).

From IEx:

    iex> BadgeForge.enqueue_batch(100)

Then run the Python worker from `python/`:

    uv sync
    uv run oban start --config oban.toml

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
