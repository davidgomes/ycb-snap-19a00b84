# Ocelot

An unofficial Oban Web Lite Dashboard

No dependency with phoenix

## Usage

Mount the dashboard in any Plug router:

```elixir
forward "/oban", to: Ocelot.Router, init_opts: [oban: Oban]
```

## Development

Run `mix dev` and open http://localhost:4000. It starts Oban on SQLite and
continuously inserts sample jobs.
