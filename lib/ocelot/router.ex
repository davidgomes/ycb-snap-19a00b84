defmodule Ocelot.Router do
  @moduledoc """
  A minimal Plug router rendering an Oban jobs dashboard.

      forward "/ocelot", Ocelot.Router, oban: Oban
  """

  use Plug.Router

  import Ecto.Query, only: [from: 2]

  @states ~w(available scheduled executing retryable completed discarded cancelled)
  @limit 50

  plug :match
  plug :dispatch, builder_opts()

  get "/" do
    render_jobs(conn, opts)
  end

  get "/api/jobs" do
    conn = Plug.Conn.fetch_query_params(conn)
    jobs = list_jobs(opts, conn.query_params["state"])

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(Enum.map(jobs, &job_to_map/1)))
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  defp render_jobs(conn, opts) do
    conn = Plug.Conn.fetch_query_params(conn)
    state = conn.query_params["state"]
    oban = Keyword.get(opts, :oban, Oban)

    counts = state_counts(oban)
    jobs = list_jobs(opts, state)

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, page(conn, state, counts, jobs))
  end

  defp list_jobs(opts, state) do
    oban = Keyword.get(opts, :oban, Oban)

    query =
      from j in Oban.Job, order_by: [desc: j.id], limit: @limit

    query =
      if state in @states, do: from(j in query, where: j.state == ^state), else: query

    Oban.Repo.all(Oban.config(oban), query)
  end

  defp state_counts(oban) do
    query = from j in Oban.Job, group_by: j.state, select: {j.state, count(j.id)}

    Oban.config(oban)
    |> Oban.Repo.all(query)
    |> Map.new()
  end

  defp job_to_map(job) do
    Map.take(job, [:id, :state, :queue, :worker, :args, :attempt, :max_attempts, :inserted_at])
  end

  defp page(conn, state, counts, jobs) do
    base = conn.script_name |> Enum.join("/") |> then(&("/" <> &1))

    tabs =
      [{"all", nil} | Enum.map(@states, &{&1, &1})]
      |> Enum.map_join(fn {label, value} ->
        count = if value, do: Map.get(counts, value, 0), else: counts |> Map.values() |> Enum.sum()
        href = if value, do: "#{base}?state=#{value}", else: base
        active = if value == state or (is_nil(value) and state not in @states), do: " class=\"active\"", else: ""
        ~s(<a href="#{href}"#{active}>#{label} <span>#{count}</span></a>)
      end)

    rows =
      Enum.map_join(jobs, fn job ->
        """
        <tr>
          <td>#{job.id}</td>
          <td><span class="state #{job.state}">#{job.state}</span></td>
          <td>#{h(job.queue)}</td>
          <td>#{h(job.worker)}</td>
          <td><code>#{h(Jason.encode!(job.args))}</code></td>
          <td>#{job.attempt}/#{job.max_attempts}</td>
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
        body { font-family: system-ui, sans-serif; margin: 0; background: #f7f7f8; color: #222; }
        header { background: #1f2937; color: #fff; padding: 1rem 2rem; font-size: 1.25rem; }
        main { padding: 1.5rem 2rem; }
        nav a { display: inline-block; margin-right: .5rem; padding: .35rem .75rem; border-radius: 4px;
                text-decoration: none; color: #374151; background: #e5e7eb; }
        nav a.active { background: #2563eb; color: #fff; }
        nav a span { opacity: .7; font-size: .85em; }
        table { width: 100%; border-collapse: collapse; margin-top: 1rem; background: #fff; }
        th, td { text-align: left; padding: .5rem .75rem; border-bottom: 1px solid #eee; font-size: .9rem; }
        th { background: #f3f4f6; }
        code { font-size: .8rem; }
        .state { padding: .1rem .4rem; border-radius: 3px; background: #e5e7eb; }
        .completed { background: #d1fae5; } .discarded, .cancelled { background: #fee2e2; }
        .executing { background: #dbeafe; } .retryable { background: #fef3c7; }
        .empty { text-align: center; color: #888; }
      </style>
    </head>
    <body>
      <header>Ocelot &middot; Oban Dashboard</header>
      <main>
        <nav>#{tabs}</nav>
        <table>
          <thead><tr><th>ID</th><th>State</th><th>Queue</th><th>Worker</th><th>Args</th><th>Attempt</th><th>Inserted</th></tr></thead>
          <tbody>#{rows}#{empty}</tbody>
        </table>
      </main>
    </body>
    </html>
    """
  end

  defp h(value), do: value |> to_string() |> Plug.HTML.html_escape()
end
