defmodule PlugRailsCookieSessionStore.Mixfile do
  use Mix.Project

  def project do
    [app: :plug_rails_cookie_session_store,
     version: "0.0.1",
     elixir: "~> 1.0",
     deps: deps()]
  end

  def application do
    [applications: [:logger, :plug]]
  end

  defp deps do
    [{:cowboy, "~> 1.0"},
     {:plug, "~> 0.9.0"}]
  end
end
