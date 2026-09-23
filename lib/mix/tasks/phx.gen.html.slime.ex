defmodule Mix.Tasks.Phx.Gen.Html.Slime do
  use Mix.Task

  @shortdoc "Generates controller, model and views for an HTML based resource using Slime templates"

  @moduledoc """
  Phoenix 1.3 style alias for `mix phoenix.gen.html.slime`.

      mix phx.gen.html.slime User users name:string age:integer
  """
  def run(args) do
    Mix.Tasks.Phoenix.Gen.Html.Slime.run(args)
  end
end
