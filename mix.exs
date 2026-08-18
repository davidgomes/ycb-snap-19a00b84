defmodule ObanDoctor.MixProject do
  use Mix.Project

  def project do
    [
      app: :oban_doctor,
      version: "0.2.2",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: "Static analysis tool for Oban workers and configuration",
      source_url: "https://github.com/tomasz-tomczyk/oban_doctor",
      homepage_url: "https://github.com/tomasz-tomczyk/oban_doctor",
      package: package(),
      docs: docs(),
      test_ignore_filters: [~r/test\/fixtures\//],
      test_coverage: [tool: ExCoveralls]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      "ecto.setup": ["ecto.create --quiet -r ObanDoctor.Test.Repo"],
      "ecto.reset": ["ecto.drop -r ObanDoctor.Test.Repo", "ecto.setup"],
      test: ["ecto.setup", "test"]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.10"},
      {:oban, "~> 2.18"},
      {:postgrex, "~> 0.17", only: :test},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/tomasz-tomczyk/oban_doctor"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      assets: %{"priv/static" => "priv/static"},
      extras: [
        "README.md",
        "guides/configuration.md",
        "guides/plugins.md"
      ],
      groups_for_modules: [
        "Worker Checks": [
          ObanDoctor.Check.Worker.MissingQueue,
          ObanDoctor.Check.Worker.StateGroupUsage,
          ObanDoctor.Check.Worker.UniquenessMissingStates,
          ObanDoctor.Check.Worker.UniqueWithoutKeys,
          ObanDoctor.Check.Worker.NoMaxAttempts
        ],
        "Config Checks": [
          ObanDoctor.Check.Config.InsertTriggerEnabled,
          ObanDoctor.Check.Config.MissingPruner,
          ObanDoctor.Check.Config.NoReindexer,
          ObanDoctor.Check.Config.SmartEngineNotConfigured
        ],
        Plugins: [
          ObanDoctor.Plugins.IndexHealth,
          ObanDoctor.Plugins.QueueMetrics,
          ObanDoctor.Plugins.TableHealth
        ],
        Internal: [
          ObanDoctor.Check,
          ObanDoctor.CLI.Output,
          ObanDoctor.Config,
          ObanDoctor.ConfigFile,
          ObanDoctor.Issue,
          ObanDoctor.ObanDiscovery,
          ObanDoctor.WorkerDiscovery
        ]
      ]
    ]
  end
end
