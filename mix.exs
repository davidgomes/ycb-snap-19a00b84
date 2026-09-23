defmodule PlugRailsCookieSessionStore.Mixfile do
  use Mix.Project

  def project do
    [
      app: :plug_rails_cookie_session_store,
      version: "0.0.1",
      elixir: "~> 1.10",
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger, :crypto]]
  end

  defp deps do
    [{:plug, "~> 1.14"}]
  end
end
