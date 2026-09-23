# Phoenix Template Engine for Slim

[![Build Status][travis-img]][travis] [![Hex Version][hex-img]][hex] [![License][license-img]][license]

> Powered by [Slime](https://github.com/slime-lang/slime)

[travis-img]: https://travis-ci.org/slime-lang/phoenix_slime.png?branch=master
[travis]: https://travis-ci.org/slime-lang/phoenix_slime
[hex-img]: https://img.shields.io/hexpm/v/phoenix_slime.svg
[hex]: https://hex.pm/packages/phoenix_slime
[license-img]: http://img.shields.io/badge/license-MIT-brightgreen.svg
[license]: http://opensource.org/licenses/MIT

## Usage

  1. Add `{:phoenix_slime, "~> 0.8.0"}` to your deps in `mix.exs`.
  2. Add the following your Phoenix `config/config.exs`:

```elixir
  config :phoenix, :template_engines,
    slim: PhoenixSlime.Engine,
    slime: PhoenixSlime.Engine
```

An example project can be found at [slime-lang/phoenix_slime_example][phoenix_slime_example].

[phoenix_slime_example]: https://github.com/slime-lang/phoenix_slime_example

## Live Reloader
In `my_app/config/dev.exs`, include the `slim` and `slime` extensions in the list of watched files.

```elixir
# Watch static and templates for browser reloading.
config :my_app, MyApp.Endpoint,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif)$},
      ~r{web/views/.*(ex)$},
      ~r{web/templates/.*(eex|slim|slime)$}
    ]
  ]
```

## Generators

This library includes `mix` tasks for Phoenix 1.2 and 1.3 generators:

`mix phoenix.gen.html.slime`
`mix phoenix.gen.layout.slime`
`mix phx.gen.html.slime`
`mix phx.gen.layout.slime`

`phoenix.gen.html.slime` creates an HTML resource the same way `phoenix.gen.html` does,
except the templates are `.slime` files instead of `.eex` files.
`phoenix.gen.layout.slime` creates `web/templates/layout/app.html.slime`.
Remove the old `app.html.eex` file after generating it.

Phoenix 1.3 prefixes its generators with `phx` and places files under `lib/`.
`phx.gen.html.slime` follows `phx.gen.html` (context, schema, and plural name)
and writes Slime templates. `phx.gen.layout.slime` writes
`lib/my_app_web/templates/layout/app.html.slime`.

Generated files have `.slime` extension by default. If you prefer `.slim`, you could add the following line to your config:

```elixir
config :phoenix_slime, :use_slim_extension, true
```

## License

MIT license. Please see [LICENSE][license] for details.

[LICENSE]: https://github.com/slime-lang/slime/blob/master/LICENSE
