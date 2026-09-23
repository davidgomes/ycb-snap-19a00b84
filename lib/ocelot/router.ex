defmodule Ocelot.Router do
  @moduledoc """
  A minimal Plug router serving the Ocelot dashboard.

  Mount it inside any Plug router:

      forward "/oban", to: Ocelot.Router, init_opts: [oban: Oban]

  Options:

    * `:oban` - the name of the Oban instance to inspect, defaults to `Oban`
  """

  use Plug.Router, copy_opts_to_assign: :ocelot_opts

  alias Ocelot.{Jobs, Templates}

  plug :fetch_query_params
  plug Plug.Parsers, parsers: [:urlencoded]
  plug :match
  plug :dispatch

  get "/" do
    oban = oban(conn)
    state = Jobs.normalize_state(conn.query_params["state"])

    content =
      Templates.index(
        base: base_path(conn),
        counts: Jobs.state_counts(oban),
        states: Jobs.states(),
        state: state,
        jobs: Jobs.list(oban, state: state, limit: Jobs.default_limit())
      )

    render(conn, 200, "Jobs", content)
  end

  get "/jobs/:id" do
    with {:ok, id} <- parse_id(id),
         %Oban.Job{} = job <- Jobs.get(oban(conn), id) do
      render(conn, 200, "Job ##{job.id}", Templates.job(base: base_path(conn), job: job))
    else
      _ -> not_found(conn)
    end
  end

  post "/jobs/:id/:action" when action in ["retry", "cancel", "delete"] do
    case parse_id(id) do
      {:ok, id} ->
        :ok = Jobs.perform_action(oban(conn), action, id)

        location =
          if action == "delete", do: base_path(conn), else: "#{base_path(conn)}/jobs/#{id}"

        redirect(conn, location)

      :error ->
        not_found(conn)
    end
  end

  match _ do
    not_found(conn)
  end

  defp oban(conn), do: Keyword.get(conn.assigns.ocelot_opts, :oban, Oban)

  defp render(conn, status, title, content) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(status, Templates.layout(title: title, base: base_path(conn), content: content))
  end

  defp redirect(conn, location) do
    conn
    |> put_resp_header("location", location)
    |> send_resp(303, "")
  end

  defp not_found(conn) do
    render(conn, 404, "Not found", Templates.not_found(base: base_path(conn)))
  end

  defp parse_id(id) do
    case Integer.parse(id) do
      {id, ""} -> {:ok, id}
      _ -> :error
    end
  end

  defp base_path(%Plug.Conn{script_name: []}), do: ""
  defp base_path(%Plug.Conn{script_name: segments}), do: "/" <> Enum.join(segments, "/")
end
