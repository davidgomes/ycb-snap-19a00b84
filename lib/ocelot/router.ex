defmodule Ocelot.Router do
  @moduledoc """
  Plug router serving the Ocelot dashboard.

  Mount it in any Plug-based application, passing the name of the Oban
  instance to inspect (defaults to `Oban`):

      forward "/oban", to: Ocelot.Router, init_opts: [oban: MyApp.Oban]
  """

  use Plug.Router, copy_opts_to_assign: :ocelot

  alias Ocelot.{Jobs, View}

  plug :match
  plug :fetch_query_params
  plug :dispatch

  get "/" do
    oban = oban(conn)
    state = param(conn, "state", Jobs.states())
    queue = param(conn, "queue")
    page = page(conn)

    {jobs, more?} = Jobs.list(oban, %{state: state, queue: queue, page: page})

    render(conn, 200, :index,
      title: "Jobs",
      counts: Jobs.state_counts(oban),
      queues: Jobs.queues(oban),
      jobs: jobs,
      more?: more?,
      state: state,
      queue: queue,
      page: page
    )
  end

  get "/jobs/:id" do
    with {id, ""} <- Integer.parse(id),
         %Oban.Job{} = job <- Jobs.get(oban(conn), id) do
      render(conn, 200, :job, title: "Job #{job.id}", job: job)
    else
      _ -> send_resp(conn, 404, "Job not found")
    end
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  defp oban(conn), do: Keyword.get(conn.assigns.ocelot, :oban, Oban)

  defp param(conn, key, allowed \\ nil) do
    case conn.query_params[key] do
      "" -> nil
      value when is_binary(value) and is_nil(allowed) -> value
      value when is_binary(value) -> if value in allowed, do: value
      _ -> nil
    end
  end

  defp page(conn) do
    case Integer.parse(conn.query_params["page"] || "") do
      {page, ""} when page > 0 -> page
      _ -> 1
    end
  end

  defp render(conn, status, template, assigns) do
    base = Enum.map_join(conn.script_name, &("/" <> &1))
    html = View.render(template, [base: base] ++ assigns)

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(status, html)
  end
end
