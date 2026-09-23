defmodule Ocelot.HTML do
  @moduledoc false

  require EEx

  # Templates don't escape output automatically: every dynamic value must go through `h/1`.
  @templates Path.expand("templates", __DIR__)

  for template <- [:layout, :jobs, :job, :not_found] do
    path = Path.join(@templates, "#{template}.html.eex")
    EEx.function_from_file(:defp, template, path, [:assigns])
  end

  def jobs_page(assigns), do: page("Jobs", assigns, jobs(assigns))

  def job_page(assigns), do: page("Job #{assigns.job.id}", assigns, job(assigns))

  def not_found_page(assigns), do: page("Not found", assigns, not_found(assigns))

  defp page(title, assigns, inner_content) do
    layout(%{title: title, base: assigns.base, inner_content: inner_content})
  end

  defp h(nil), do: ""
  defp h(value), do: value |> to_string() |> Plug.HTML.html_escape()

  defp jobs_path(base, params \\ []) do
    params =
      Enum.reject(params, fn {key, value} -> is_nil(value) or {key, value} == {:page, 1} end)

    path = if base == "", do: "/", else: base

    if params == [], do: path, else: path <> "?" <> URI.encode_query(params)
  end

  defp job_path(base, id), do: "#{base}/jobs/#{id}"

  defp active_class(true), do: "active"
  defp active_class(false), do: ""

  defp total(counts), do: Enum.reduce(counts, 0, fn {_key, count}, acc -> acc + count end)

  defp json(term), do: Jason.encode!(term, pretty: true)

  defp preview(term, max_length \\ 80) do
    encoded = Jason.encode!(term)

    if String.length(encoded) > max_length do
      String.slice(encoded, 0, max_length) <> "…"
    else
      encoded
    end
  end

  defp list(nil), do: "—"
  defp list([]), do: "—"
  defp list(values), do: Enum.join(values, ", ")

  defp timestamp(nil), do: "—"

  defp timestamp(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp timestamp(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> timestamp(datetime)
      {:error, _reason} -> value
    end
  end

  defp relative_time(nil, _now), do: "—"

  defp relative_time(datetime, now) do
    case DateTime.diff(now, datetime) do
      seconds when seconds >= 0 -> "#{duration(seconds)} ago"
      seconds -> "in #{duration(-seconds)}"
    end
  end

  defp duration(seconds) when seconds < 60, do: "#{seconds}s"
  defp duration(seconds) when seconds < 3_600, do: "#{div(seconds, 60)}m"
  defp duration(seconds) when seconds < 86_400, do: "#{div(seconds, 3_600)}h"
  defp duration(seconds), do: "#{div(seconds, 86_400)}d"

  defp state_time(%{state: "executing"} = job), do: job.attempted_at
  defp state_time(%{state: "completed"} = job), do: job.completed_at
  defp state_time(%{state: "cancelled"} = job), do: job.cancelled_at
  defp state_time(%{state: "discarded"} = job), do: job.discarded_at
  defp state_time(job), do: job.scheduled_at
end
