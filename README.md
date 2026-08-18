# Ocelot

An unofficial Oban Web Lite Dashboard

No dependency with phoenix

## Usage

Mount `Ocelot.Router` anywhere in a Plug pipeline:

```elixir
forward "/oban", to: Ocelot.Router, init_opts: [oban_name: Oban]
```

The dashboard lists the most recent jobs and lets you filter them by state.

## Development

```sh
mix deps.get
mix dev
```

This boots a SQLite backed Oban instance with a few demo jobs and serves the
dashboard on http://localhost:4000.
