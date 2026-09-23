defmodule PlugRailsCookieSessionStore.Mixfile do
  use Mix.Project

  def project do
    [app: :plug_rails_cookie_session_store,
     version: "0.0.1",
     elixir: "~> 0.15.0",
     deps: deps,
     description: "Rails compatible Plug session store"]
  end

  def application do
    [applications: [:crypto, :plug]]
  end

  defp deps do
    [{:plug, "~> 0.5.3"}]
  end
end
