defmodule Mix.Tasks.Phx.Gen.Layout.Slime do
  use Mix.Task

  @shortdoc "Generates a default Phoenix layout file in Slime"

  @moduledoc """
  Generates a Phoenix layout file in Slime.

      mix phx.gen.layout.slime

  """
  def run(_args) do
    if Mix.Project.umbrella? do
      Mix.raise "mix phx.gen.layout.slime can only be run inside an application directory"
    end

    context_app = Mix.Phoenix.context_app()
    binding = [app_module: Mix.Phoenix.context_base(context_app)]

    extension = PhoenixSlime.ConfiguredExtension.file_extension
    layout_path = Mix.Phoenix.web_path(context_app, "templates/layout/app.html.#{extension}")

    Mix.Phoenix.copy_from slime_paths(), "priv/templates/phx.gen.layout.slime", binding, [
      {:eex, "app.html.eex",       layout_path}
    ]

    instructions = """

    A new #{layout_path} file was generated.
    """
    Mix.shell.info instructions
  end

  defp slime_paths do
    [".", :phoenix_slime]
  end
end
