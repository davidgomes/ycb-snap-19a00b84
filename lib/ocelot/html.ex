defmodule Ocelot.HTML do
  @moduledoc false

  require EEx

  alias Oban.Job

  @templates Path.join(__DIR__, "templates")

  for template <- [:layout, :jobs, :job, :not_found] do
    EEx.function_from_file(
      :def,
      template,
      Path.join(@templates, "#{template}.html.eex"),
      [:assigns],
      engine: Ocelot.HTML.Engine
    )
  end

  @doc """
  Renders `template` with `assigns`, wrapped in the layout.
  """
  def render(template, assigns) do
    inner = apply(__MODULE__, template, [assigns])

    assigns
    |> Map.put(:inner_content, raw(inner))
    |> layout()
  end

  def raw(markup), do: {:safe, markup}

  def escape({:safe, markup}), do: IO.iodata_to_binary(markup)
  def escape(nil), do: ""
  def escape(list) when is_list(list), do: Enum.map_join(list, &escape/1)
  def escape(value), do: value |> to_string() |> Plug.HTML.html_escape()

  def jobs_path(base, params) do
    case params |> Enum.reject(fn {_key, value} -> is_nil(value) end) |> URI.encode_query() do
      "" -> base <> "/"
      query -> base <> "/?" <> query
    end
  end

  def job_path(base, %Job{id: id}), do: base <> "/jobs/#{id}"

  @doc """
  The timestamp that best describes a job's current state.
  """
  def state_timestamp(%Job{} = job) do
    case job.state do
      "executing" -> {"attempted", job.attempted_at}
      "completed" -> {"completed", job.completed_at}
      "discarded" -> {"discarded", job.discarded_at}
      "cancelled" -> {"cancelled", job.cancelled_at}
      _ -> {"scheduled", job.scheduled_at}
    end
  end

  def format_datetime(nil), do: "—"

  def format_datetime(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
  end

  def relative_time(datetime, now \\ DateTime.utc_now())

  def relative_time(nil, _now), do: "—"

  def relative_time(%DateTime{} = datetime, now) do
    case DateTime.diff(datetime, now) do
      0 -> "now"
      diff when diff < 0 -> humanize(-diff) <> " ago"
      diff -> "in " <> humanize(diff)
    end
  end

  defp humanize(seconds) when seconds < 60, do: "#{seconds}s"
  defp humanize(seconds) when seconds < 3_600, do: "#{div(seconds, 60)}m"
  defp humanize(seconds) when seconds < 86_400, do: "#{div(seconds, 3_600)}h"
  defp humanize(seconds), do: "#{div(seconds, 86_400)}d"

  def truncate(string, max) do
    if String.length(string) > max do
      String.slice(string, 0, max - 1) <> "…"
    else
      string
    end
  end
end
