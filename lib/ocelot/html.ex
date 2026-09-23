defmodule Ocelot.HTML do
  @moduledoc false

  require EEx

  @templates Path.join(__DIR__, "templates")

  EEx.function_from_file(:defp, :layout, Path.join(@templates, "layout.html.eex"), [:assigns])

  EEx.function_from_file(:defp, :dashboard_body, Path.join(@templates, "dashboard.html.eex"), [
    :assigns
  ])

  EEx.function_from_file(:defp, :job_body, Path.join(@templates, "job.html.eex"), [:assigns])

  def dashboard(assigns) do
    layout(Keyword.merge(assigns, title: "Jobs", content: dashboard_body(assigns)))
  end

  def job(assigns) do
    layout(Keyword.merge(assigns, title: "Job #{assigns[:job].id}", content: job_body(assigns)))
  end

  def not_found(assigns) do
    content =
      ~s(<section class="card"><h2>Not found</h2><p><a href="#{h(assigns[:base])}/">Back to jobs</a></p></section>)

    layout(Keyword.merge(assigns, title: "Not found", content: content))
  end

  defp h(nil), do: ""
  defp h(value) when is_binary(value), do: Plug.HTML.html_escape(value)
  defp h(value), do: value |> to_string() |> Plug.HTML.html_escape()

  defp jobs_url(base, filters) do
    query =
      filters
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> URI.encode_query()

    if query == "", do: base <> "/", else: base <> "/?" <> query
  end

  defp format_time(nil), do: "—"

  defp format_time(%DateTime{} = time) do
    time |> DateTime.truncate(:second) |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_time(%NaiveDateTime{} = time) do
    time |> NaiveDateTime.truncate(:second) |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
  end

  defp relevant_time(%Oban.Job{} = job) do
    case job.state do
      "completed" -> job.completed_at
      "discarded" -> job.discarded_at
      "cancelled" -> job.cancelled_at
      "executing" -> job.attempted_at
      _ -> job.scheduled_at
    end
  end

  defp pretty_json(value), do: Jason.encode!(value, pretty: true)
end
