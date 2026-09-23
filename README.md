# Ocelot

An unofficial Oban Web Lite Dashboard

No dependency with phoenix

## Usage

Mount the dashboard in any Plug (or Phoenix) router:

```elixir
forward "/oban", to: Ocelot.Router, init_opts: [oban: Oban]
```

## Development

```sh
mix deps.get
mix dev
```

Then open http://localhost:4000/oban.
