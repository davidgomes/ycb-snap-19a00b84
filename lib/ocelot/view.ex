defmodule Ocelot.View do
  @moduledoc false

  require EEx

  @templates Path.join(__DIR__, "templates")

  EEx.function_from_file(:def, :layout, Path.join(@templates, "layout.html.eex"), [:assigns])
  EEx.function_from_file(:def, :index, Path.join(@templates, "index.html.eex"), [:assigns])
  EEx.function_from_file(:def, :show, Path.join(@templates, "show.html.eex"), [:assigns])
  EEx.function_from_file(:def, :not_found, Path.join(@templates, "not_found.html.eex"), [:assigns])

  def h(nil), do: ""
  def h(value) when is_binary(value), do: Plug.HTML.html_escape(value)
  def h(value), do: value |> to_string() |> h()

  def json(value), do: value |> Jason.encode!(pretty: true) |> h()

  def timestamp(nil), do: "—"
  def timestamp(%DateTime{} = at), do: at |> DateTime.truncate(:second) |> DateTime.to_iso8601()
end
