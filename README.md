# Ocelot

An unofficial Oban Web Lite Dashboard

No dependency with phoenix

## Usage

Mount `Ocelot.Router` in your Plug router:

```elixir
forward "/oban", to: Ocelot.Router
```

Or in your Phoenix router:

```elixir
forward "/oban", Ocelot.Router
```

It reads jobs through the Oban instance named `Oban` by default. Use the `:oban` option to pick
another one, e.g. `forward "/oban", to: Ocelot.Router, init_opts: [oban: MyApp.Oban]`.

The dashboard lists jobs filtered by state and queue, and shows the details of each job
(args, meta, errors and timestamps). It doesn't authenticate requests, so protect the mount
point in your own pipeline.
