defmodule Mix.Tasks.Phx.Gen.Layout.Slime do
  use Mix.Task

  @shortdoc "Generates a default Phoenix 1.3 layout file in Slime"

  @moduledoc """
  Generates a Phoenix 1.3 layout file in Slime.

      mix phx.gen.layout.slime

  """
  def run(_args) do
    if Mix.Project.umbrella? do
      Mix.raise "mix phx.gen.layout.slime can only be run inside an application directory"
    end

    binding = [app_module: Mix.Phoenix.base()]
    extension = PhoenixSlime.ConfiguredExtension.file_extension
    path = Mix.Phoenix.web_path(Mix.Phoenix.context_app(), "templates/layout/app.html.#{extension}")

    Mix.Phoenix.copy_from slime_paths(), "priv/templates/phx.gen.layout.slime", binding, [
      {:eex, "app.html.eex", path}
    ]

    Mix.shell.info """

    A new #{path} file was generated.
    """
  end

  defp slime_paths do
    [".", :phoenix_slime]
  end
end
