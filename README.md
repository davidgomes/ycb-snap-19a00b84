# BadgeForge

A demo application showcasing interoperability between Elixir and Python via [Oban](https://github.com/oban-bg/oban).

## Overview

This project demonstrates how to use Oban to coordinate background jobs between an Elixir application and a Python worker. The Elixir app enqueues jobs that are processed by Python (using WeasyPrint to generate badge PDFs).

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
