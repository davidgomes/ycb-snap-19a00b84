defmodule Ocelot.Router do
  @moduledoc false

  use Plug.Router

  alias Ocelot.{HTML, Queries}

  @states Enum.map(Oban.Job.states(), &Atom.to_string/1)

  plug(:match)
  plug(:fetch_query_params)
  plug(:dispatch)

  get "/" do
    redirect(conn, conn.private.ocelot.base <> "/jobs")
  end

  get "/jobs" do
    %{conf: conf, base: base} = conn.private.ocelot
    state = parse_state(conn.query_params["state"])
    page = parse_page(conn.query_params["page"])

    {jobs, total_pages} = Queries.list_jobs(conf, state: state, page: page)
    counts = Queries.state_counts(conf)

    html(conn, 200, HTML.job_list(jobs, counts, state, page, total_pages, base))
  end

  get "/jobs/:id" do
    %{conf: conf, base: base} = conn.private.ocelot

    with {id, ""} <- Integer.parse(id),
         %Oban.Job{} = job <- Queries.get_job(conf, id) do
      html(conn, 200, HTML.job_detail(job, base))
    else
      _ -> html(conn, 404, HTML.not_found(base))
    end
  end

  match _ do
    html(conn, 404, HTML.not_found(conn.private.ocelot.base))
  end

  defp html(conn, status, body) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(status, body)
  end

  defp redirect(conn, to) do
    conn
    |> put_resp_header("location", to)
    |> send_resp(302, "")
  end

  defp parse_state(state) when state in @states, do: state
  defp parse_state(_state), do: nil

  defp parse_page(nil), do: 1

  defp parse_page(page) do
    case Integer.parse(page) do
      {n, ""} when n > 0 -> n
      _ -> 1
    end
  end
end
