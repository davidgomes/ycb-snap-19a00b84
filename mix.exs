defmodule ObanNotifiersPhoenix.MixProject do
  use Mix.Project

  @source_url "https://github.com/sorentwo/oban_notifiers_phoenix"
  @version "0.1.0"

  def project do
    [
      app: :oban_notifiers_phoenix,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      name: "Oban Notifiers Phoenix",
      description: "Oban notifier built on Phoenix.PubSub",
      source_url: @source_url
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
        "GitHub" => @source_url
      }
    ]
  end

  defp docs do
    [
      main: "Oban.Notifiers.Phoenix",
      source_ref: "v#{@version}",
      formatters: ["html"],
      extras: ["CHANGELOG.md"]
    ]
  end

  defp deps do
    [
      {:oban, "~> 2.17"},
      {:phoenix_pubsub, "~> 2.0"},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false}
    ]
  end
end
