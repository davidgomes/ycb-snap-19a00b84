defmodule Ocelot.View do
  @moduledoc false

  require EEx

  @templates Path.join(__DIR__, "templates")

  for name <- ~w(layout index job)a do
    file = Path.join(@templates, "#{name}.html.eex")
    @external_resource file
    EEx.function_from_file(:defp, name, file, [:assigns])
  end

  def render(template, assigns) do
    assigns = Map.new(assigns)
    inner = apply_template(template, assigns)

    layout(Map.put(assigns, :inner, inner))
  end

  defp apply_template(:index, assigns), do: index(assigns)
  defp apply_template(:job, assigns), do: job(assigns)

  defp h(nil), do: ""
  defp h(value), do: value |> to_string() |> Plug.HTML.html_escape()

  defp json(value, opts \\ []), do: Jason.encode!(value, opts)

  defp datetime(nil), do: "—"
  defp datetime(%DateTime{} = dt), do: dt |> DateTime.truncate(:second) |> DateTime.to_string()

  defp datetime(%NaiveDateTime{} = dt),
    do: dt |> NaiveDateTime.truncate(:second) |> NaiveDateTime.to_string()

  defp path(base, path, params \\ []) do
    query =
      params
      |> Enum.reject(fn {key, value} -> is_nil(value) or (key == :page and value == 1) end)
      |> URI.encode_query()

    h(base <> path <> if(query == "", do: "", else: "?" <> query))
  end
end
