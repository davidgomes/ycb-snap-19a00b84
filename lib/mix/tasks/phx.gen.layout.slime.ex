defmodule Mix.Tasks.Phx.Gen.Layout.Slime do
  use Mix.Task

  @shortdoc "Generates a default Phoenix layout file in Slime"

  @moduledoc """
  Generates a Phoenix layout file in Slime.

      mix phx.gen.layout.slime

  """
  def run(_args) do
    binding = [application_module: Mix.Phoenix.base()]

    extension = PhoenixSlime.ConfiguredExtension.file_extension()
    web_prefix = Mix.Phoenix.web_path(Mix.Phoenix.context_app())

    Mix.Phoenix.copy_from(slime_paths(), "priv/templates/phx.gen.layout.slime", binding, [
      {:eex, "app.html.eex", Path.join([web_prefix, "templates", "layout", "app.html.#{extension}"])}
    ])

    instructions = """

    A new #{web_prefix}/templates/layout/app.html.#{extension} file was generated.
    """
    Mix.shell.info(instructions)
  end

  defp slime_paths do
    [".", :phoenix_slime]
  end
end
