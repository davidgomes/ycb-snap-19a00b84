defmodule Ocelot.View do
  @moduledoc """
  Renders the dashboard HTML.
  """

  @columns ~w(id state queue worker attempt inserted_at)a

  @doc """
  Renders the dashboard page for the given jobs, counts and selected state.
  """
  def render(assigns) do
    """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Ocelot</title>
        <style>#{style()}</style>
      </head>
      <body>
        <header>
          <h1>Ocelot</h1>
          <p>An unofficial Oban Web Lite Dashboard</p>
        </header>
        <nav>#{filters(assigns.counts, assigns.state, assigns.base_path)}</nav>
        <main>#{table(assigns.jobs)}</main>
      </body>
    </html>
    """
  end

  defp filters(counts, current, base_path) do
    all_count = counts |> Map.values() |> Enum.sum()

    entries =
      [{nil, "all", all_count}] ++
        Enum.map(Ocelot.Jobs.states(), fn state -> {state, state, Map.get(counts, state, 0)} end)

    Enum.map_join(entries, fn {state, label, count} ->
      class = if state == current, do: ~s( class="active"), else: ""
      href = if state, do: "#{base_path}?state=#{state}", else: base_path

      ~s(<a#{class} href="#{escape(href)}">#{escape(label)} <span>#{count}</span></a>)
    end)
  end

  defp table([]) do
    ~s(<p class="empty">No jobs found.</p>)
  end

  defp table(jobs) do
    head = Enum.map_join(@columns, &"<th>#{&1}</th>")

    rows =
      Enum.map_join(jobs, fn job ->
        cells = Enum.map_join(@columns, &"<td>#{escape(value(job, &1))}</td>")
        "<tr>#{cells}</tr>"
      end)

    "<table><thead><tr>#{head}</tr></thead><tbody>#{rows}</tbody></table>"
  end

  defp value(job, :attempt), do: "#{job.attempt}/#{job.max_attempts}"
  defp value(job, key), do: job |> Map.fetch!(key) |> to_string()

  defp escape(value) do
    value |> Plug.HTML.html_escape() |> IO.iodata_to_binary()
  end

  defp style do
    """
    * { box-sizing: border-box; }
    body { margin: 0; padding: 2rem; font: 14px/1.5 ui-sans-serif, system-ui, sans-serif;
           color: #1f2933; background: #f5f7fa; }
    header h1 { margin: 0; font-size: 1.5rem; }
    header p { margin: .25rem 0 1.5rem; color: #616e7c; }
    nav { display: flex; flex-wrap: wrap; gap: .5rem; margin-bottom: 1rem; }
    nav a { padding: .35rem .75rem; border-radius: 999px; background: #fff; border: 1px solid #d9e2ec;
            color: #334e68; text-decoration: none; }
    nav a.active { background: #334e68; border-color: #334e68; color: #fff; }
    nav a span { opacity: .7; }
    table { width: 100%; border-collapse: collapse; background: #fff; border: 1px solid #d9e2ec;
            border-radius: 6px; overflow: hidden; }
    th, td { padding: .5rem .75rem; text-align: left; border-bottom: 1px solid #f0f4f8; }
    th { background: #f0f4f8; font-size: 12px; text-transform: uppercase; letter-spacing: .04em; }
    tbody tr:last-child td { border-bottom: 0; }
    .empty { color: #616e7c; }
    """
  end
end
