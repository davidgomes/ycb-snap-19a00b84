defmodule GenQueueOban.MixProject do
  use Mix.Project

  @project_url "https://github.com/Trax-retail/gen_queue_oban"
  @version "0.1.0"

  def project do
    [
      app: :gen_queue_oban,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases(),
      description: description(),
      package: package(),
      name: "GenQueue Oban",
      source_url: @project_url,
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    """
    GenQueue adapter for Oban
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Trax Retail"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @project_url,
        "GenQueue" => "https://github.com/nsweeting/gen_queue",
        "Oban" => "https://github.com/sorentwo/oban"
      }
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @project_url
    ]
  end

  defp deps do
    [
      {:gen_queue, "~> 0.1.8"},
      {:oban, "~> 0.10"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
