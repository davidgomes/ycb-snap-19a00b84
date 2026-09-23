defmodule Ocelot do
  @moduledoc """
  A lightweight Oban dashboard served as a plain Plug.

      forward "/ocelot", Ocelot, repo: MyApp.Repo

  Options:
    * `:repo` - the Ecto repo Oban uses (required)
    * `:prefix` - the Oban table prefix (default `"public"`)
    * `:limit` - max jobs listed (default `50`)
  """

  @behaviour Plug

  import Plug.Conn
  import Ecto.Query

  @states ~w(available scheduled executing retryable completed discarded cancelled)

  @impl true
  def init(opts) do
    Keyword.fetch!(opts, :repo)
    Keyword.merge([prefix: "public", limit: 50], opts)
  end

  @impl true
  def call(%Plug.Conn{method: "GET", path_info: []} = conn, opts) do
    conn = fetch_query_params(conn)
    state = Map.get(conn.query_params, "state")
    state = if state in @states, do: state

    html = render(counts(opts), jobs(opts, state), state, conn.script_name)

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  def call(conn, _opts), do: send_resp(conn, 404, "Not Found")

  defp counts(opts) do
    query =
      from j in Oban.Job,
        group_by: j.state,
        select: {j.state, count(j.id)}

    counts = Map.new(opts[:repo].all(query, prefix: opts[:prefix]))
    Enum.map(@states, &{&1, Map.get(counts, &1, 0)})
  end

  defp jobs(opts, state) do
    query =
      from j in Oban.Job,
        order_by: [desc: j.id],
        limit: ^opts[:limit]

    query = if state, do: where(query, [j], j.state == ^state), else: query

    opts[:repo].all(query, prefix: opts[:prefix])
  end

  defp render(counts, jobs, current, script_name) do
    base = "/" <> Enum.join(script_name, "/")

    tabs =
      [{nil, "all", Enum.sum(Enum.map(counts, &elem(&1, 1)))} | Enum.map(counts, fn {s, c} -> {s, s, c} end)]
      |> Enum.map(fn {state, label, count} ->
        href = if state, do: "#{base}?state=#{state}", else: base
        class = if state == current, do: ~s( class="active"), else: ""
        ~s(<a href="#{href}"#{class}>#{label} <span>#{count}</span></a>)
      end)

    rows =
      Enum.map(jobs, fn job ->
        """
        <tr>
          <td>#{job.id}</td>
          <td>#{esc(job.worker)}</td>
          <td>#{esc(job.queue)}</td>
          <td><span class="state #{job.state}">#{job.state}</span></td>
          <td>#{job.attempt}/#{job.max_attempts}</td>
          <td><code>#{esc(Jason.encode!(job.args))}</code></td>
          <td>#{job.inserted_at}</td>
        </tr>
        """
      end)

    empty = if jobs == [], do: ~s(<tr><td colspan="7" class="empty">No jobs</td></tr>), else: ""

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Ocelot</title>
      <style>
        body { font-family: system-ui, sans-serif; margin: 2rem; color: #222; }
        nav a { margin-right: .5rem; padding: .3rem .6rem; border-radius: 4px; text-decoration: none; color: #333; background: #eee; }
        nav a.active { background: #333; color: #fff; }
        nav span { opacity: .7; font-size: .85em; }
        table { width: 100%; border-collapse: collapse; margin-top: 1.5rem; font-size: .9rem; }
        th, td { text-align: left; padding: .4rem .6rem; border-bottom: 1px solid #ddd; }
        code { font-size: .8rem; }
        .state { padding: .1rem .4rem; border-radius: 3px; background: #eee; }
        .completed { background: #d4f5d4; } .discarded, .cancelled { background: #f5d4d4; }
        .executing { background: #d4e4f5; } .retryable { background: #f5ecd4; }
        .empty { text-align: center; color: #888; }
      </style>
    </head>
    <body>
      <h1>Ocelot</h1>
      <nav>#{tabs}</nav>
      <table>
        <thead><tr><th>ID</th><th>Worker</th><th>Queue</th><th>State</th><th>Attempt</th><th>Args</th><th>Inserted</th></tr></thead>
        <tbody>#{rows}#{empty}</tbody>
      </table>
    </body>
    </html>
    """
  end

  defp esc(value), do: value |> to_string() |> Plug.HTML.html_escape()
end
