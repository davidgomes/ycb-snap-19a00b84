defmodule PlugRailsCookieSessionStore.Mixfile do
  use Mix.Project

  def project do
    [app: :plug_rails_cookie_session_store,
     version: "0.0.1",
     elixir: "~> 1.0",
     description: description(),
     package: package(),
     deps: deps()]
  end

  def application do
    [applications: [:logger, :plug]]
  end

  defp deps do
    [{:plug, "~> 1.0"}]
  end

  defp description do
    """
    Rails compatible Plug session store.
    """
  end

  defp package do
    [licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/cconstantin/plug_rails_cookie_session_store"}]
  end
end
