# Ocelot

An unofficial Oban Web Lite Dashboard

No dependency with phoenix

## Usage

Mount `Ocelot` in any `Plug.Router`:

```elixir
forward "/oban", to: Ocelot
```

To inspect an Oban instance with a custom name, pass `init_opts: [oban: MyApp.Oban]`.

The dashboard lists jobs (filterable by state, paginated) and shows the details of each job:
args, meta, timestamps and errors.

## Development

```sh
mix deps.get
mix dev
```

Then visit http://localhost:4000/oban. The dev server uses a local SQLite database in `db/`.
