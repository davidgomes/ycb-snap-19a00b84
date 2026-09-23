defmodule Mix.Tasks.Phx.Gen.Layout.Slime do
  use Mix.Task

  @shortdoc "Generates a default Phoenix layout file in Slime"

  @moduledoc """
  Phoenix 1.3 style alias for `mix phoenix.gen.layout.slime`.

      mix phx.gen.layout.slime
  """
  def run(args) do
    Mix.Tasks.Phoenix.Gen.Layout.Slime.run(args)
  end
end
