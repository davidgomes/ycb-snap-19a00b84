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

      # Hex
      description: "Oban notifier built on Phoenix.PubSub",
      name: "Oban Notifiers Phoenix",
      source_url: @source_url
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp package do
    [
      maintainers: ["Parker Selbert"],
      licenses: ["Apache-2.0"],
      files: ~w(lib .formatter.exs mix.exs README* CHANGELOG* LICENSE*),
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
      source_url: @source_url,
      extras: ["CHANGELOG.md": [title: "Changelog"]],
      formatters: ["html"]
    ]
  end

  defp deps do
    [
      {:oban, "~> 2.16"},
      {:phoenix_pubsub, "~> 2.0"},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false}
    ]
  end
end
