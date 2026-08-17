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

This library also includes `mix` tasks for Phoenix 1.3 (`phx.*`) and the
older `phoenix.*` generators:

`mix phx.gen.html.slime`
`mix phx.gen.layout.slime`
`mix phoenix.gen.html.slime`
`mix phoenix.gen.layout.slime`

`phx.gen.html.slime` creates an HTML resource the same way `phx.gen.html` does,
except templates use `.slime` instead of `.eex`.

`phx.gen.layout.slime` writes `lib/APP_web/templates/layout/app.html.slime`
with the same content as `app.html.eex`. Remove the old `app.html.eex` file
after generating.

Generated files have `.slime` extension by default. If you prefer `.slim`, you could add the following line to your config:

```elixir
config :phoenix_slime, :use_slim_extension, true
```

## License

MIT license. Please see [LICENSE][license] for details.

[LICENSE]: https://github.com/slime-lang/slime/blob/master/LICENSE
