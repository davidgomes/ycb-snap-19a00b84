defmodule Mix.Tasks.Phx.Gen.Html.Slime do
  use Mix.Task

  alias Mix.Phoenix.{Context, Schema}
  alias Mix.Tasks.Phx.Gen

  @shortdoc "Generates controller, views, and context for an HTML resource using Slime templates"

  @moduledoc """
  This file was adapted from the original Phoenix html generator found here:

  https://github.com/phoenixframework/phoenix/blob/v1.3.0/lib/mix/tasks/phx.gen.html.ex

  Generates controller, views, and context for an HTML resource.

      mix phx.gen.html.slime Accounts User users name:string age:integer

  The first argument is the context module followed by the schema module
  and its plural name (used as the schema table name).

  Overall, this generator will add the following files to `lib/`:

    * a context module in lib/app/accounts/accounts.ex for the accounts API
    * a schema in lib/app/accounts/user.ex, with an `users` table
    * a view in lib/app_web/views/user_view.ex
    * a controller in lib/app_web/controllers/user_controller.ex
    * default CRUD Slime templates in lib/app_web/templates/user

  A migration file for the repository and test files for the context and
  controller features will also be generated.

  The generator accepts the same options as `phx.gen.html`, such as
  `--web`, `--no-context`, `--no-schema`, `--table`, `--binary-id` and
  `--context-app`. Read the documentation for `phx.gen.html` and
  `phx.gen.schema` for more information on options and attributes.
  """

  @doc false
  def run(args) do
    if Mix.Project.umbrella? do
      Mix.raise "mix phx.gen.html.slime can only be run inside an application directory"
    end
    {context, schema} = Gen.Context.build(args)
    binding = [context: context, schema: schema, inputs: inputs(schema)]

    prompt_for_conflicts(context)

    context
    |> copy_new_files(binding)
    |> Gen.Html.print_shell_instructions()
  end

  defp prompt_for_conflicts(context) do
    context
    |> phoenix_files()
    |> Kernel.++(slime_files(context))
    |> Kernel.++(context_files(context))
    |> Mix.Phoenix.prompt_for_conflicts()
  end

  defp context_files(%Context{generate?: true} = context) do
    Gen.Context.files_to_be_generated(context)
  end
  defp context_files(%Context{generate?: false}) do
    []
  end

  defp phoenix_files(%Context{schema: schema, context_app: context_app}) do
    web_prefix = Mix.Phoenix.web_path(context_app)
    test_prefix = Mix.Phoenix.web_test_path(context_app)
    web_path = to_string(schema.web_path)

    [
      {:eex, "controller.ex",       Path.join([web_prefix, "controllers", web_path, "#{schema.singular}_controller.ex"])},
      {:eex, "view.ex",             Path.join([web_prefix, "views", web_path, "#{schema.singular}_view.ex"])},
      {:eex, "controller_test.exs", Path.join([test_prefix, "controllers", web_path, "#{schema.singular}_controller_test.exs"])},
    ]
  end

  defp slime_files(%Context{schema: schema, context_app: context_app}) do
    template_path = Path.join([Mix.Phoenix.web_path(context_app), "templates", to_string(schema.web_path), schema.singular])
    extension = PhoenixSlime.ConfiguredExtension.file_extension

    [
      {:eex, "edit.html.eex",       Path.join(template_path, "edit.html.#{extension}")},
      {:eex, "form.html.eex",       Path.join(template_path, "form.html.#{extension}")},
      {:eex, "index.html.eex",      Path.join(template_path, "index.html.#{extension}")},
      {:eex, "new.html.eex",        Path.join(template_path, "new.html.#{extension}")},
      {:eex, "show.html.eex",       Path.join(template_path, "show.html.#{extension}")},
    ]
  end

  defp copy_new_files(%Context{} = context, binding) do
    paths = Mix.Phoenix.generator_paths()

    Mix.Phoenix.copy_from paths, "priv/templates/phx.gen.html", binding, phoenix_files(context)
    Mix.Phoenix.copy_from slime_paths(), "priv/templates/phx.gen.html.slime", binding, slime_files(context)
    if context.generate?, do: Gen.Context.copy_new_files(context, paths, binding)
    context
  end

  defp inputs(%Schema{} = schema) do
    Enum.map(schema.attrs, fn
      {_, {:array, _}} ->
        {nil, nil, nil}
      {_, {:references, _}} ->
        {nil, nil, nil}
      {key, :integer} ->
        {label(key), ~s(= number_input f, #{inspect(key)}, class: "form-control"), error(key)}
      {key, :float} ->
        {label(key), ~s(= number_input f, #{inspect(key)}, step: "any", class: "form-control"), error(key)}
      {key, :decimal} ->
        {label(key), ~s(= number_input f, #{inspect(key)}, step: "any", class: "form-control"), error(key)}
      {key, :boolean} ->
        {label(key), ~s(= checkbox f, #{inspect(key)}, class: "checkbox"), error(key)}
      {key, :text} ->
        {label(key), ~s(= textarea f, #{inspect(key)}, class: "form-control"), error(key)}
      {key, :date} ->
        {label(key), ~s(= date_select f, #{inspect(key)}, class: "form-control"), error(key)}
      {key, :time} ->
        {label(key), ~s(= time_select f, #{inspect(key)}, class: "form-control"), error(key)}
      {key, :utc_datetime} ->
        {label(key), ~s(= datetime_select f, #{inspect(key)}, class: "form-control"), error(key)}
      {key, :naive_datetime} ->
        {label(key), ~s(= datetime_select f, #{inspect(key)}, class: "form-control"), error(key)}
      {key, _}  ->
        {label(key), ~s(= text_input f, #{inspect(key)}, class: "form-control"), error(key)}
    end)
  end

  defp label(key) do
    ~s(= label f, #{inspect(key)}, class: "control-label")
  end

  defp error(field) do
    ~s(= error_tag f, #{inspect(field)})
  end

  defp slime_paths do
    [".", :phoenix_slime]
  end
end
