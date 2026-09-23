defmodule ObanDoctor.MixProject do
  use Mix.Project

  def project do
    [
      app: :oban_doctor,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Static analysis tool for Oban workers and configuration",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      groups_for_modules: [
        Checks: [
          ObanDoctor.Check.Worker.MissingQueue,
          ObanDoctor.Check.Worker.StateGroupUsage,
          ObanDoctor.Check.Worker.UniquenessMissingStates,
          ObanDoctor.Check.Worker.UniqueWithoutKeys,
          ObanDoctor.Check.Worker.NoMaxAttempts
        ]
      ]
    ]
  end
end
