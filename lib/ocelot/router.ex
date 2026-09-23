defmodule Ocelot.Router do
  @moduledoc """
  A plug serving the Ocelot dashboard.

  Mount it inside any Plug router:

      forward "/oban", to: Ocelot.Router, init_opts: [oban: Oban]

  ## Options

    * `:oban` - the name of the Oban instance to inspect. Defaults to `Oban`.
  """

  use Plug.Router, copy_opts_to_assign: :ocelot

  alias Ocelot.{HTML, Queries}

  @page_size 50

  plug :match
  plug :dispatch

  get "/" do
    conn = fetch_query_params(conn)
    conf = oban_conf(conn)
    filters = parse_filters(conn.query_params)

    body =
      HTML.dashboard(
        base: base_path(conn),
        filters: filters,
        state_counts: Queries.state_counts(conf),
        queue_counts: Queries.queue_counts(conf),
        jobs: Queries.list_jobs(conf, filters, @page_size),
        page_size: @page_size
      )

    send_html(conn, 200, body)
  end

  get "/jobs/:id" do
    conf = oban_conf(conn)

    with {id, ""} <- Integer.parse(id),
         %Oban.Job{} = job <- Queries.get_job(conf, id) do
      send_html(conn, 200, HTML.job(base: base_path(conn), job: job))
    else
      _ -> send_html(conn, 404, HTML.not_found(base: base_path(conn)))
    end
  end

  match _ do
    send_html(conn, 404, HTML.not_found(base: base_path(conn)))
  end

  defp oban_conf(conn) do
    conn.assigns.ocelot
    |> Keyword.get(:oban, Oban)
    |> Oban.config()
  end

  defp parse_filters(params) do
    state = params["state"]
    queue = params["queue"]

    %{
      state: if(state in Queries.states(), do: state),
      queue: if(is_binary(queue) and queue != "", do: queue)
    }
  end

  defp base_path(%Plug.Conn{script_name: []}), do: ""
  defp base_path(%Plug.Conn{script_name: segments}), do: "/" <> Enum.join(segments, "/")

  defp send_html(conn, status, body) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(status, body)
  end
end
