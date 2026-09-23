# Ocelot

An unofficial Oban Web Lite Dashboard

No dependency with phoenix

## Usage

Mount `Ocelot.Router` in any Plug router:

```elixir
forward "/oban", to: Ocelot.Router, init_opts: [oban: Oban]
```

Or in a Phoenix router:

```elixir
forward "/oban", Ocelot.Router, oban: Oban
```

The `:oban` option is the name of the Oban instance to inspect and defaults to `Oban`.

The dashboard lists jobs by state and queue and shows the args, meta and errors of each job.
It does not include authentication, so mount it behind your own.

## Development

```sh
mix deps.get
mix dev
```

This starts an Oban instance backed by SQLite (stored in `db/`), enqueues sample jobs and
serves the dashboard at http://localhost:4000/oban.
