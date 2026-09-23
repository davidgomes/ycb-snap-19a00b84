defmodule Mix.Tasks.Phx.Gen.Html.Slime do
  use Mix.Task

  alias Mix.Phoenix.Context
  alias Mix.Tasks.Phx.Gen

  @shortdoc "Generates controller, views, and context for an HTML resource using Slime templates"

  @moduledoc """
  This file was adapted from the original Phoenix html generator found here:

  https://github.com/phoenixframework/phoenix/blob/v1.3/lib/mix/tasks/phx.gen.html.ex

  Generates controller, views, and context for an HTML resource.

      mix phx.gen.html.slime Accounts User users name:string age:integer

  The first argument is the context module followed by the schema module
  and its plural name (used as the schema table name).

  Read the documentation for `phx.gen.html` for more information.
  """
  def run(args) do
    if Mix.Project.umbrella? do
      Mix.raise "mix phx.gen.html.slime can only be run inside an application directory"
    end

    {context, schema} = Gen.Context.build(args)
    Gen.Context.prompt_for_code_injection(context)

    binding = [context: context, schema: schema, inputs: inputs(schema)]
    paths = Mix.Phoenix.generator_paths()

    prompt_for_conflicts(context)

    context
    |> copy_new_files(paths, binding)
    |> Gen.Html.print_shell_instructions()
  end

  defp prompt_for_conflicts(context) do
    context
    |> files_to_be_generated()
    |> Kernel.++(Gen.Context.files_to_be_generated(context))
    |> Mix.Phoenix.prompt_for_conflicts()
  end

  defp files_to_be_generated(%Context{schema: schema}) do
    web_prefix = Mix.Phoenix.web_prefix()
    test_prefix = Mix.Phoenix.test_prefix()
    web_path = to_string(schema.web_path)
    extension = PhoenixSlime.ConfiguredExtension.file_extension
    templates = Path.join([web_prefix, "templates", web_path, schema.singular])

    [
      {:eex, "controller.ex", Path.join([web_prefix, "controllers", web_path, "#{schema.singular}_controller.ex"])},
      {:eex, "view.ex", Path.join([web_prefix, "views", web_path, "#{schema.singular}_view.ex"])},
      {:eex, "controller_test.exs", Path.join([test_prefix, "controllers", web_path, "#{schema.singular}_controller_test.exs"])},
      {:slime, "edit.html.eex", Path.join(templates, "edit.html.#{extension}")},
      {:slime, "form.html.eex", Path.join(templates, "form.html.#{extension}")},
      {:slime, "index.html.eex", Path.join(templates, "index.html.#{extension}")},
      {:slime, "new.html.eex", Path.join(templates, "new.html.#{extension}")},
      {:slime, "show.html.eex", Path.join(templates, "show.html.#{extension}")},
    ]
  end

  defp copy_new_files(%Context{} = context, paths, binding) do
    {slime_files, phoenix_files} =
      context
      |> files_to_be_generated()
      |> Enum.split_with(fn {type, _, _} -> type == :slime end)

    Mix.Phoenix.copy_from paths, "priv/templates/phx.gen.html", binding, phoenix_files

    slime_files = Enum.map(slime_files, fn {_, source, target} -> {:eex, source, target} end)
    Mix.Phoenix.copy_from [".", :phoenix_slime], "priv/templates/phx.gen.html.slime", binding, slime_files

    Gen.Context.copy_new_files(context, paths, binding)
    context
  end

  defp inputs(schema) do
    Enum.map schema.attrs, fn
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
      {key, _} ->
        {label(key), ~s(= text_input f, #{inspect(key)}, class: "form-control"), error(key)}
    end
  end

  defp label(key) do
    ~s(= label f, #{inspect(key)}, class: "control-label")
  end

  defp error(field) do
    ~s(= error_tag f, #{inspect(field)})
  end
end
