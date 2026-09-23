# Ocelot

An unofficial Oban Web Lite Dashboard

No dependency with phoenix

## Usage

`Ocelot.Router` is a plain `Plug`, so it can be mounted in any Plug or Phoenix router.

```elixir
# Plug.Router
forward "/oban", to: Ocelot.Router, init_opts: [oban: MyApp.Oban]

# Phoenix.Router
forward "/oban", Ocelot.Router, oban: MyApp.Oban
```

The `:oban` option is the name of the Oban instance to inspect and defaults to `Oban`.

The dashboard lists jobs by state, with counts for each state, and shows the details of a job:
its args, meta, timestamps and errors.

## Development

```sh
mix deps.get
mix dev
```

This starts Oban on a local SQLite database (under `db/`) with some sample jobs and serves the
dashboard at http://localhost:4000/oban.
