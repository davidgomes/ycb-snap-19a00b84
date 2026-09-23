defmodule Ocelot.Router do
  @moduledoc """
  A Plug serving a lightweight dashboard for inspecting Oban jobs.

  Mount it inside any Plug router:

      forward "/oban", to: Ocelot.Router

  ## Options

    * `:oban` - name of the running Oban instance to inspect, defaults to `Oban`

  For example:

      forward "/oban", to: Ocelot.Router, init_opts: [oban: MyApp.Oban]
  """

  use Plug.Router

  alias Ocelot.{HTML, Queries}

  plug(:match)
  plug(:fetch_query_params)
  plug(:dispatch)

  def init(opts), do: Keyword.put_new(opts, :oban, Oban)

  def call(conn, opts) do
    conn
    |> put_private(:ocelot_oban, opts[:oban])
    |> super(opts)
  end

  get "/" do
    conf = oban_conf(conn)
    state = parse_state(conn.query_params["state"])
    page = parse_page(conn.query_params["page"])

    {jobs, total} = Queries.list_jobs(conf, state: state, page: page)
    counts = Queries.state_counts(conf)
    total_pages = max(ceil(total / Queries.page_size()), 1)

    html(conn, 200, HTML.index(jobs, counts, state, page, total_pages, base(conn)))
  end

  get "/jobs/:id" do
    with {id, ""} <- Integer.parse(id),
         %Oban.Job{} = job <- Queries.get_job(oban_conf(conn), id) do
      html(conn, 200, HTML.job(job, base(conn)))
    else
      _ -> html(conn, 404, HTML.not_found(base(conn)))
    end
  end

  match _ do
    html(conn, 404, HTML.not_found(base(conn)))
  end

  defp html(conn, status, body) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(status, body)
  end

  defp oban_conf(conn), do: Oban.config(conn.private.ocelot_oban)

  defp base(conn), do: Enum.map_join(conn.script_name, &("/" <> &1))

  defp parse_state(state) do
    if state in HTML.states(), do: state
  end

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {page, ""} when page > 0 -> page
      _ -> 1
    end
  end

  defp parse_page(_page), do: 1
end
