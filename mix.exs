defmodule GenQueueOban.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :gen_queue_oban,
      version: @version,
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      description: "GenQueue adapter for Oban",
      package: package(),
      docs: [main: "readme", extras: ["README.md"], source_ref: "v#{@version}"],
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/Trax-retail/gen_queue_oban"}
    ]
  end

  defp deps do
    [
      {:gen_queue, "~> 0.1.8"},
      {:oban, "~> 0.4"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
