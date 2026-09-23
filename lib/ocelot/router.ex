defmodule Ocelot.Router do
  @moduledoc """
  A `Plug` serving the Ocelot dashboard.

  Mount it in a `Plug.Router`:

      forward "/oban", to: Ocelot.Router, init_opts: [oban: MyApp.Oban]

  Or in a Phoenix router:

      forward "/oban", Ocelot.Router, oban: MyApp.Oban

  ## Options

    * `:oban` - the name of the Oban instance to inspect. Defaults to `Oban`.
  """

  use Plug.Router

  alias Ocelot.{HTML, Jobs}

  @per_page 50

  plug :match
  plug :dispatch

  @impl true
  def init(opts), do: Keyword.validate!(opts, oban: Oban)

  @impl true
  def call(conn, opts) do
    conn
    |> put_private(:ocelot_oban, Keyword.fetch!(opts, :oban))
    |> super(opts)
  end

  get "/" do
    conn = fetch_query_params(conn)
    conf = oban_conf(conn)
    state = parse_state(conn.query_params["state"])
    page = parse_page(conn.query_params["page"])

    counts = Jobs.count_by_state(conf)
    all_count = counts |> Enum.map(&elem(&1, 1)) |> Enum.sum()
    count = if state, do: counts |> List.keyfind!(state, 0) |> elem(1), else: all_count
    jobs = Jobs.list(conf, state: state, limit: @per_page, offset: (page - 1) * @per_page)

    render(conn, 200, :jobs,
      title: if(state, do: "#{String.capitalize(state)} jobs", else: "Jobs"),
      state: state,
      counts: counts,
      all_count: all_count,
      jobs: jobs,
      page: page,
      total_pages: max(ceil(count / @per_page), 1)
    )
  end

  get "/jobs/:id" do
    with {id, ""} <- Integer.parse(id),
         %Oban.Job{} = job <- Jobs.get(oban_conf(conn), id) do
      render(conn, 200, :job, title: "Job #{job.id}", job: job)
    else
      _ -> render_not_found(conn, "Job #{id} doesn't exist.")
    end
  end

  match _ do
    render_not_found(conn, "This page doesn't exist.")
  end

  defp oban_conf(conn), do: Oban.config(conn.private.ocelot_oban)

  # Where the router is mounted, e.g. "/oban", or "" at the root.
  defp base_path(conn), do: Enum.map_join(conn.script_name, &("/" <> &1))

  defp parse_state(state) do
    if state in Jobs.states(), do: state
  end

  defp parse_page(nil), do: 1

  defp parse_page(page) do
    case Integer.parse(page) do
      {page, ""} when page > 0 -> page
      _ -> 1
    end
  end

  defp render_not_found(conn, message) do
    render(conn, 404, :not_found, title: "Not found", message: message)
  end

  defp render(conn, status, template, assigns) do
    assigns =
      assigns
      |> Map.new()
      |> Map.merge(%{base: base_path(conn), oban: conn.private.ocelot_oban})

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(status, HTML.render(template, assigns))
  end
end
