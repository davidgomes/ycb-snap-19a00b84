# Ocelot

An unofficial Oban Web Lite Dashboard

No dependency with phoenix

## Usage

Mount the router in any Plug application, passing your Oban instance name:

```elixir
forward "/oban", to: Ocelot.Router, init_opts: [oban: Oban]
```

## Development

`mix dev` starts a SQLite-backed Oban with sample jobs and serves the
dashboard at http://localhost:4000/oban.
