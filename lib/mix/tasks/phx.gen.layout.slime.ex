defmodule Mix.Tasks.Phx.Gen.Layout.Slime do
  use Mix.Task

  @shortdoc "Generates a default Phoenix layout file in Slime"

  @moduledoc """
  Generates a Phoenix layout file in Slime.

      mix phx.gen.layout.slime

  """
  def run(_args) do
    binding = [application_module: Mix.Phoenix.base()]
    extension = PhoenixSlime.ConfiguredExtension.file_extension
    target = Path.join([Mix.Phoenix.web_prefix(), "templates", "layout", "app.html.#{extension}"])

    Mix.Phoenix.copy_from [".", :phoenix_slime], "priv/templates/phx.gen.layout.slime", binding, [
      {:eex, "app.html.eex", target}
    ]

    Mix.shell.info """

    A new #{target} file was generated.
    """
  end
end
