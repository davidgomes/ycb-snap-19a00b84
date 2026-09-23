# Ocelot

An unofficial Oban Web Lite Dashboard

No dependency with phoenix

## Usage

Forward a path to `Ocelot.Router` from any Plug router in an application
running Oban:

```elixir
forward "/oban", to: Ocelot.Router
```

Pass `init_opts: [oban: MyApp.Oban]` to inspect an Oban instance with a custom
name.

The dashboard lists jobs newest first, filterable by state, and links to a
detail page per job showing its args, meta and errors.
