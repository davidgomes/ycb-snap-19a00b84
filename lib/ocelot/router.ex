defmodule Ocelot.Router do
  @moduledoc """
  A plug that serves the Ocelot dashboard.

  Mount it from any `Plug.Router`:

      forward "/oban", to: Ocelot.Router, init_opts: [oban: Oban]

  Or from a Phoenix router:

      forward "/oban", Ocelot.Router, oban: Oban

  The dashboard exposes job args, meta and errors, so mount it behind your
  application's authentication.

  ## Options

    * `:oban` - the name of the Oban instance to inspect. Defaults to `Oban`.
  """

  use Plug.Router

  alias Ocelot.{Jobs, View}

  @max_id 9_223_372_036_854_775_807

  plug :match
  plug :dispatch

  @impl Plug
  def init(opts), do: Keyword.put_new(opts, :oban, Oban)

  @impl Plug
  def call(conn, opts) do
    conn
    |> put_private(:ocelot, opts)
    |> super(opts)
  end

  get "/" do
    conf = oban_config(conn)
    conn = fetch_query_params(conn)
    filters = Jobs.parse_filters(conn.query_params)
    {jobs, has_more} = Jobs.list(conf, filters)

    render(conn, 200, :jobs,
      title: View.jobs_title(filters),
      filters: filters,
      jobs: jobs,
      has_more: has_more,
      states: Jobs.states(),
      state_counts: Jobs.count_by_state(conf, filters),
      queue_counts: Jobs.count_by_queue(conf, filters)
    )
  end

  get "/jobs/:id" do
    conf = oban_config(conn)

    with {id, ""} when id > 0 and id <= @max_id <- Integer.parse(id),
         %Oban.Job{} = job <- Jobs.get(conf, id) do
      render(conn, 200, :job, title: "#{job.worker} ##{job.id}", job: job)
    else
      _ -> not_found(conn, "Job #{id} does not exist.")
    end
  end

  match _ do
    not_found(conn, "There is nothing at this address.")
  end

  defp not_found(conn, message) do
    render(conn, 404, :not_found, title: "Not found", message: message)
  end

  defp render(conn, status, template, assigns) do
    assigns =
      assigns
      |> Map.new()
      |> Map.merge(%{
        base: "/" <> Enum.join(conn.script_name, "/"),
        oban: conn.private.ocelot[:oban],
        now: DateTime.utc_now()
      })

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(status, View.render(template, assigns))
  end

  defp oban_config(conn), do: Oban.config(conn.private.ocelot[:oban])
end
