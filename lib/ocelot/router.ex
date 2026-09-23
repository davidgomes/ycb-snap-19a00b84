defmodule Ocelot.Router do
  @moduledoc """
  A minimal Oban dashboard as a plain Plug.

      forward "/ocelot", Ocelot.Router, oban: Oban
  """

  use Plug.Router

  import Ecto.Query, only: [from: 2]

  @states ~w(available scheduled executing retryable completed discarded cancelled)

  plug :match
  plug :dispatch, builder_opts()

  get "/" do
    oban = Keyword.get(opts, :oban, Oban)
    conf = Oban.config(oban)
    state = conn |> fetch_query_params() |> Map.get(:query_params) |> Map.get("state")
    state = if state in @states, do: state, else: nil

    counts =
      Oban.Repo.all(
        conf,
        from(j in Oban.Job, group_by: j.state, select: {j.state, count(j.id)})
      )
      |> Map.new()

    query = from(j in Oban.Job, order_by: [desc: j.id], limit: 100)
    query = if state, do: from(j in query, where: j.state == ^state), else: query
    jobs = Oban.Repo.all(conf, query)

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, render(conn, counts, jobs, state))
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  defp render(conn, counts, jobs, current) do
    base = conn.script_name |> Enum.join("/") |> then(&("/" <> &1))

    tabs =
      Enum.map_join([nil | @states], "", fn state ->
        href = if state, do: "#{base}?state=#{state}", else: base
        label = state || "all"
        count = if state, do: Map.get(counts, state, 0), else: counts |> Map.values() |> Enum.sum()
        class = if state == current, do: ~s( class="active"), else: ""
        ~s(<a href="#{href}"#{class}>#{label} <span>#{count}</span></a>)
      end)

    rows =
      Enum.map_join(jobs, "", fn job ->
        """
        <tr>
          <td>#{job.id}</td>
          <td>#{esc(job.worker)}</td>
          <td>#{esc(job.queue)}</td>
          <td>#{job.state}</td>
          <td>#{job.attempt}/#{job.max_attempts}</td>
          <td><code>#{esc(Jason.encode!(job.args))}</code></td>
          <td>#{job.inserted_at}</td>
        </tr>
        """
      end)

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Ocelot</title>
      <style>
        body { font-family: system-ui, sans-serif; margin: 2rem; color: #222; }
        nav a { margin-right: .75rem; text-decoration: none; color: #555; }
        nav a.active { color: #000; font-weight: bold; }
        nav span { background: #eee; border-radius: 8px; padding: 0 .4rem; font-size: .8em; }
        table { border-collapse: collapse; width: 100%; margin-top: 1rem; }
        th, td { text-align: left; padding: .4rem .6rem; border-bottom: 1px solid #eee; font-size: .9em; }
        code { font-size: .85em; }
      </style>
    </head>
    <body>
      <h1>Ocelot</h1>
      <nav>#{tabs}</nav>
      <table>
        <thead><tr><th>ID</th><th>Worker</th><th>Queue</th><th>State</th><th>Attempt</th><th>Args</th><th>Inserted</th></tr></thead>
        <tbody>#{rows}</tbody>
      </table>
    </body>
    </html>
    """
  end

  defp esc(value), do: value |> to_string() |> Plug.HTML.html_escape()
end
