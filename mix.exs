defmodule PlugRailsCookieSessionStore.Mixfile do
  use Mix.Project

  def project do
    [
      app: :plug_rails_cookie_session_store,
      version: "0.1.0",
      elixir: "~> 1.3",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [applications: [:logger, :plug]]
  end

  defp deps do
    [
      {:plug, "~> 1.0"}
    ]
  end

  defp description do
    "Rails compatible Plug session store"
  end

  defp package do
    [
      maintainers: [],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/cconstantin/plug_rails_cookie_session_store"}
    ]
  end
end
