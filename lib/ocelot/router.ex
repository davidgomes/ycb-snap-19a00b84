defmodule Ocelot.Router do
  @moduledoc """
  A Plug that serves the Ocelot dashboard.

  Mount it from a `Plug.Router`:

      forward "/oban", to: Ocelot.Router

  or from a Phoenix router:

      forward "/oban", Ocelot.Router

  ## Options

    * `:oban` - the name of the Oban instance to inspect. Defaults to `Oban`.

  Ocelot doesn't authenticate requests, so make sure the mount point is protected
  by your own pipeline.
  """

  use Plug.Router

  alias Ocelot.{HTML, Queries}

  @per_page 25

  plug(:match)
  plug(:fetch_query_params)
  plug(:dispatch)

  @impl Plug
  def init(opts), do: Keyword.validate!(opts, oban: Oban)

  @impl Plug
  def call(conn, opts) do
    conn
    |> put_private(:ocelot_oban, Keyword.fetch!(opts, :oban))
    |> super(opts)
  end

  get "/" do
    conf = oban_config(conn)
    params = conn.query_params
    states = Enum.map(Oban.Job.states(), &Atom.to_string/1)
    state = if params["state"] in states, do: params["state"]
    queue = if is_binary(params["queue"]) and params["queue"] != "", do: params["queue"]
    page = parse_page(params["page"])

    {jobs, next_page?} =
      Queries.list_jobs(conf, state: state, queue: queue, page: page, per_page: @per_page)

    html(
      conn,
      200,
      HTML.jobs_page(%{
        base: base_path(conn),
        now: DateTime.utc_now(),
        jobs: jobs,
        states: states,
        state: state,
        state_counts: Queries.state_counts(conf, queue: queue),
        queues: Queries.queue_counts(conf),
        queue: queue,
        page: page,
        next_page?: next_page?
      })
    )
  end

  get "/jobs/:id" do
    conf = oban_config(conn)

    with {job_id, ""} <- Integer.parse(id),
         %Oban.Job{} = job <- Queries.get_job(conf, job_id) do
      html(conn, 200, HTML.job_page(%{base: base_path(conn), now: DateTime.utc_now(), job: job}))
    else
      _ -> not_found(conn, "Job #{id} not found")
    end
  end

  match _ do
    not_found(conn, "Page not found")
  end

  defp oban_config(conn), do: Oban.config(conn.private.ocelot_oban)

  defp base_path(conn), do: Enum.map_join(conn.script_name, &("/" <> &1))

  defp parse_page(value) when is_binary(value) do
    case Integer.parse(value) do
      {page, ""} when page > 0 -> page
      _ -> 1
    end
  end

  defp parse_page(_value), do: 1

  defp not_found(conn, message) do
    html(conn, 404, HTML.not_found_page(%{base: base_path(conn), message: message}))
  end

  defp html(conn, status, body) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(status, body)
  end
end
