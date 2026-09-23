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
      name: "Oban Notifiers Phoenix",
      source_url: @source_url
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp docs do
    [
      main: "Oban.Notifiers.Phoenix",
      source_ref: "v#{@version}",
      source_url: @source_url,
      formatters: ["html"],
      extras: ["CHANGELOG.md"]
    ]
  end

  defp deps do
    [
      {:oban, "~> 2.16", github: "sorentwo/oban"},
      {:phoenix_pubsub, "~> 2.0"},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false}
    ]
  end
end
