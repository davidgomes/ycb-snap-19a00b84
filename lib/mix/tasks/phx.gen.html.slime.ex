defmodule Mix.Tasks.Phx.Gen.Html.Slime do
  use Mix.Task

  @shortdoc "Generates controller, context and views for an HTML based resource using Slime templates"

  @moduledoc """
  Generates a Phoenix resource.

      mix phx.gen.html.slime Accounts User users name:string age:integer

  The first argument is the context module followed by
  the schema module and its plural name (used for resources and schema).

  The generated resource will contain:

    * a context module in lib/foo/accounts/accounts.ex
    * a schema in lib/foo/accounts/user.ex
    * a view in lib/foo_web/views/user_view.ex
    * a controller in lib/foo_web/controllers/user_controller.ex
    * default CRUD templates in lib/foo_web/templates/user
    * test files for generated context and controller resources
    * test helpers
    * a migration file for the repository

  Read the documentation for `phx.gen.schema` for more information
  on attributes.
  """

  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise "mix phx.gen.html.slime must be invoked from within your *_web application root directory"
    end

    Mix.Tasks.Phx.Gen.Html.run(args, [
      {:slime, "priv/templates/phx.gen.html.slime", PhoenixSlime.ConfiguredExtension.file_extension()}
    ])
  end
end
