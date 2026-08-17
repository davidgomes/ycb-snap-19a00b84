defmodule BadgeForge.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BadgeForge.Repo,
      {Phoenix.PubSub, name: BadgeForge.PubSub},
      {Oban, Application.fetch_env!(:badge_forge, Oban)},
      BadgeForgeWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: BadgeForge.Supervisor]

    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    BadgeForgeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
