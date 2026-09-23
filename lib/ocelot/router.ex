defmodule Ocelot.Router do
  @moduledoc """
  Plug serving the Ocelot dashboard.

  Mount it in any Plug or Phoenix router:

      forward "/oban", to: Ocelot.Router, init_opts: [oban: Oban]

  ## Options

    * `:oban` - name of the Oban instance to inspect. Defaults to `Oban`.
    * `:limit` - maximum number of jobs listed per page. Defaults to `100`.
  """

  use Plug.Router

  alias Ocelot.{Jobs, View}

  plug :match
  plug :dispatch

  @impl Plug
  def init(opts) do
    opts
    |> Keyword.put_new(:oban, Oban)
    |> Keyword.put_new(:limit, 100)
  end

  @impl Plug
  def call(conn, opts) do
    conn
    |> put_private(:ocelot, opts)
    |> super(opts)
  end

  get "/" do
    conn = fetch_query_params(conn)
    oban = conn.private.ocelot[:oban]
    state = Map.get(conn.query_params, "state", "available")
    state = if state in Jobs.states(), do: state, else: "available"

    render(conn, 200, &View.index/1,
      state: state,
      state_counts: Jobs.state_counts(oban),
      queue_counts: Jobs.queue_counts(oban),
      jobs: Jobs.list_jobs(oban, state, conn.private.ocelot[:limit])
    )
  end

  get "/jobs/:id" do
    oban = conn.private.ocelot[:oban]

    with {id, ""} <- Integer.parse(id),
         %Oban.Job{} = job <- Jobs.get_job(oban, id) do
      render(conn, 200, &View.show/1, job: job)
    else
      _ -> render(conn, 404, &View.not_found/1, [])
    end
  end

  match _ do
    render(conn, 404, &View.not_found/1, [])
  end

  defp render(conn, status, template, assigns) do
    base = Enum.map_join(conn.script_name, &["/", &1])
    body = View.layout(base: base, inner: template.([{:base, base} | assigns]))

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(status, body)
  end
end
