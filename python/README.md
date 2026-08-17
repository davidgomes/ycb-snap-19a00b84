# BadgeForge Python Worker

This package is the Python side of BadgeForge's Oban bridge. [Oban for
Python](https://github.com/oban-bg/oban-py) reads and writes the same
`oban_jobs` Postgres table as [Oban for
Elixir](https://github.com/oban-bg/oban), so no message broker or RPC layer
is needed to move jobs between the two runtimes: enqueue a job from Elixir
(see `BadgeForge.Badges`) and this worker picks it up.

## Setup

```
cd python
uv venv && source .venv/bin/activate
uv pip install -e .
```

The Oban schema (the `oban_jobs`, `oban_leaders`, and `oban_producers`
tables) is already installed by the Elixir app's
`priv/repo/migrations/20260126170721_add_oban.exs` migration, so there's no
separate schema install step — both runtimes share it.

## Run the worker

Point `--dsn` at the same database configured in `config/dev.exs`:

```
oban start --dsn postgresql://postgres:postgres@localhost/badge_forge_dev --queues badges:5
```

With the worker running, enqueue jobs from Elixir with `mix badges.forge` (or
`BadgeForge.Badges.enqueue/1`) and watch them get processed here.
