defmodule GenQueueOban.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :gen_queue_oban,
      version: @version,
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      name: "GenQueue Oban",
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
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
      files: ["lib", "mix.exs", "README*"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/Trax-retail/gen_queue_oban",
        "GenQueue" => "https://github.com/nsweeting/gen_queue"
      }
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme",
      source_url: "https://github.com/Trax-retail/gen_queue_oban"
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gen_queue, "~> 0.1.8"},
      {:oban, "~> 0.10"},
      {:ecto_sql, "~> 3.1", only: :test},
      {:postgrex, "~> 0.14", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
