defmodule PlugRailsCookieSessionStore.Mixfile do
  use Mix.Project

  def project do
    [
      app: :plug_rails_cookie_session_store,
      version: "0.1.0",
      elixir: "~> 1.10",
      description: "Rails compatible Plug session store",
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [{:plug, "~> 1.14"}]
  end
end
