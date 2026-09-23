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

    binding = [application_module: Mix.Phoenix.base()]

    extension = PhoenixSlime.ConfiguredExtension.file_extension
    target = Mix.Phoenix.web_path(Mix.Phoenix.otp_app(), "templates/layout/app.html.#{extension}")
    Mix.Phoenix.copy_from slime_paths(), "priv/templates/phx.gen.layout.slime", binding, [
      {:eex, "app.html.eex", target}
    ]

    instructions = """

    A new #{target} file was generated.
    """
    Mix.shell.info instructions
  end

  defp slime_paths do
    [".", :phoenix_slime]
  end
end
