# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :badge_forge, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  queues: [default: 10, printing: 5],
  repo: BadgeForge.Repo

config :badge_forge,
  ecto_repos: [BadgeForge.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :badge_forge, BadgeForgeWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: BadgeForgeWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: BadgeForge.PubSub,
  live_view: [signing_salt: "2Ds4hqHh"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, JSON

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
