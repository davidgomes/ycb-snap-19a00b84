defmodule Mix.Tasks.Phx.Gen.Layout.Slime do
  use Mix.Task

  @shortdoc "Generates a default Phoenix layout file in Slime"

  @moduledoc """
  Generates a Phoenix layout file in Slime.

      mix phx.gen.layout.slime

  """
  def run(_args) do
    web_prefix = Mix.Phoenix.web_path(Mix.Phoenix.context_app())
    binding = [application_module: "ApplicationName"]

    extension = PhoenixSlime.ConfiguredExtension.file_extension
    layout_path = Path.join([web_prefix, "templates", "layout", "app.html.#{extension}"])
    Mix.Phoenix.copy_from slime_paths(), "priv/templates/phx.gen.layout.slime", binding, [
      {:eex, "app.html.eex", layout_path}
    ]

    Mix.shell.info """

    A new #{layout_path} file was generated.
    """
  end

  defp slime_paths do
    [".", :phoenix_slime]
  end
end
