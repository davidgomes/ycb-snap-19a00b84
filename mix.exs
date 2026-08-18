defmodule PlugRailsCookieSessionStore.Mixfile do
  use Mix.Project

  def project do
    [app: :plug_rails_cookie_session_store,
     version: "0.1.0",
     elixir: "~> 1.0",
     description: "Rails compatible Plug session store",
     package: package,
     deps: deps]
  end

  def application do
    [applications: [:logger, :plug]]
  end

  defp deps do
    [{:plug, "~> 0.9"}]
  end

  defp package do
    %{licenses: ["Apache 2"],
      links: %{"Github" => "https://github.com/cconstantin/plug_rails_cookie_session_store"}}
  end
end
