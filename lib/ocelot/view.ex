defmodule Ocelot.View do
  @moduledoc false

  require EEx

  @templates_path Path.expand("templates", __DIR__)

  for name <- [:layout, :jobs, :job, :not_found] do
    path = Path.join(@templates_path, "#{name}.html.eex")
    @external_resource path
    EEx.function_from_file(:defp, :"#{name}_template", path, [:assigns],
      engine: Ocelot.HTML.Engine
    )
  end

  def render(template, assigns) do
    inner_content = render_template(template, assigns)
    {:safe, html} = layout_template(Map.put(assigns, :inner_content, inner_content))
    html
  end

  defp render_template(:jobs, assigns), do: jobs_template(assigns)
  defp render_template(:job, assigns), do: job_template(assigns)
  defp render_template(:not_found, assigns), do: not_found_template(assigns)

  def jobs_title(%{state: nil, queue: nil}), do: "All jobs"
  def jobs_title(%{state: nil, queue: queue}), do: "All jobs in #{queue}"
  def jobs_title(%{state: state, queue: nil}), do: "#{String.capitalize(state)} jobs"

  def jobs_title(%{state: state, queue: queue}),
    do: "#{String.capitalize(state)} jobs in #{queue}"

  def jobs_path(base, params) do
    query =
      for key <- [:state, :queue, :page],
          value = params[key],
          not (key == :page and value == 1),
          do: {key, value}

    case URI.encode_query(query) do
      "" -> base
      query -> base <> "?" <> query
    end
  end

  def job_path(base, %{id: id}), do: String.trim_trailing(base, "/") <> "/jobs/#{id}"

  def active_class(true), do: "active"
  def active_class(false), do: ""

  def total(counts), do: counts |> Map.values() |> Enum.sum()

  def job_time(%{state: state} = job) do
    field =
      case state do
        "executing" -> :attempted_at
        "completed" -> :completed_at
        "discarded" -> :discarded_at
        "cancelled" -> :cancelled_at
        state when state in ["available", "scheduled", "retryable"] -> :scheduled_at
        _ -> :inserted_at
      end

    case Map.fetch!(job, field) do
      nil -> {"inserted", job.inserted_at}
      at -> {field |> Atom.to_string() |> String.trim_trailing("_at"), at}
    end
  end

  def timeline(job) do
    for field <- [
          :inserted_at,
          :scheduled_at,
          :attempted_at,
          :completed_at,
          :discarded_at,
          :cancelled_at
        ],
        at = Map.fetch!(job, field) do
      {field |> Atom.to_string() |> String.trim_trailing("_at") |> String.capitalize(), at}
    end
    |> Enum.sort_by(&elem(&1, 1), DateTime)
  end

  def relative_time(at, now) do
    seconds = DateTime.diff(at, now, :second)

    cond do
      seconds == 0 -> "just now"
      seconds < 0 -> "#{duration(-seconds)} ago"
      true -> "in #{duration(seconds)}"
    end
  end

  defp duration(seconds) when seconds < 60, do: "#{seconds}s"
  defp duration(seconds) when seconds < 3_600, do: "#{div(seconds, 60)}m"
  defp duration(seconds) when seconds < 86_400, do: "#{div(seconds, 3_600)}h"
  defp duration(seconds), do: "#{div(seconds, 86_400)}d"

  def iso8601(%DateTime{} = at), do: at |> DateTime.truncate(:second) |> DateTime.to_iso8601()

  def json(term, opts \\ []), do: Jason.encode!(term, opts)

  def truncate(string, max) do
    if String.length(string) > max do
      String.slice(string, 0, max - 1) <> "…"
    else
      string
    end
  end
end
