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
      aliases: aliases(),
      preferred_cli_env: ["test.ci": :test],

      # Hex
      package: package(),
      description: """
      An Oban.Notifier that uses Phoenix.PubSub for notifications.
      """,

      # Docs
      name: "Oban.Notifiers.Phoenix",
      docs: [
        main: "Oban.Notifiers.Phoenix",
        api_reference: false,
        source_ref: "v#{@version}",
        source_url: @source_url,
        formatters: ["html"],
        extras: ["CHANGELOG.md": [filename: "changelog", title: "Changelog"]],
        skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
      ]
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
        Changelog: "#{@source_url}/blob/main/CHANGELOG.md",
        GitHub: @source_url
      }
    ]
  end

  defp deps do
    [
      {:oban, "~> 2.17"},
      {:phoenix_pubsub, "~> 2.0"},
      {:ex_doc, "~> 0.28", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      release: [
        "cmd git tag v#{@version}",
        "cmd git push",
        "cmd git push --tags",
        "hex.publish --yes"
      ],
      "test.ci": [
        "format --check-formatted",
        "deps.unlock --check-unused",
        "compile --warnings-as-errors",
        "test --raise"
      ]
    ]
  end
end
