defmodule Ocelot.Templates do
  @moduledoc false

  require EEx

  @templates_dir Path.join(__DIR__, "templates")

  for name <- ~w(layout index job not_found)a do
    path = Path.join(@templates_dir, "#{name}.html.eex")
    @external_resource path
    EEx.function_from_file(:def, name, path, [:assigns])
  end

  def h(nil), do: ""

  def h(value) when is_binary(value) do
    value
    |> Plug.HTML.html_escape_to_iodata()
    |> IO.iodata_to_binary()
  end

  def h(value), do: value |> to_string() |> h()

  def format_time(nil), do: "-"
  def format_time(%DateTime{} = time), do: time |> DateTime.truncate(:second) |> to_string()

  def format_time(%NaiveDateTime{} = time),
    do: time |> NaiveDateTime.truncate(:second) |> to_string()

  def format_json(term), do: Jason.encode!(term, pretty: true)

  def cancellable?(%Oban.Job{state: state}),
    do: state in ~w(available scheduled executing retryable)

  def retryable?(%Oban.Job{state: state}),
    do: state in ~w(scheduled retryable completed discarded cancelled)

  def deletable?(%Oban.Job{state: state}), do: state != "executing"
end
