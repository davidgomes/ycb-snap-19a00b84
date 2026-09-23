defmodule Ocelot.View do
  @moduledoc false

  require EEx

  for name <- [:layout, :index, :show, :not_found] do
    path = Path.join([__DIR__, "templates", "#{name}.html.eex"])
    EEx.function_from_file(:def, name, path, [:assigns])
  end

  def h(nil), do: ""
  def h(value) when is_binary(value), do: Plug.HTML.html_escape(value)
  def h(value), do: value |> to_string() |> h()

  def json(value), do: value |> Jason.encode!(pretty: true) |> h()

  def timestamp(nil), do: "—"
  def timestamp(%DateTime{} = at), do: at |> DateTime.truncate(:second) |> DateTime.to_iso8601()
end
