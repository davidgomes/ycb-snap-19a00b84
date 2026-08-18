defmodule Mix.Tasks.Phx.Gen.Layout.Slime do
  use Mix.Task

  @shortdoc "Generates a default Phoenix layout file in Slime"

  @moduledoc """
  Generates a Phoenix layout file in Slime.

      mix phx.gen.layout.slime

  """
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise "mix phx.gen.layout.slime must be invoked from within your *_web application root directory"
    end

    Mix.Tasks.Phx.Gen.Layout.run(args, [
      {:slime, "priv/templates/phx.gen.layout.slime", PhoenixSlime.ConfiguredExtension.file_extension()}
    ])
  end
end
