defmodule PlugRailsCookieSessionStore.MixProject do
  use Mix.Project

  def project do
    [
      app: :plug_rails_cookie_session_store,
      version: "0.1.0",
      elixir: "~> 1.15",
      description: "Rails compatible Plug session store",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.20"},
      {:plug_crypto, "~> 2.0"}
    ]
  end
end
