defmodule Ocelot.Router do
  @moduledoc """
  Plug router serving the Ocelot dashboard.

  Mount it in any Plug pipeline:

      forward "/oban", to: Ocelot.Router, init_opts: [oban_name: Oban]
  """

  use Plug.Router

  plug :match
  plug Plug.Parsers, parsers: [:urlencoded]
  plug :dispatch, builder_opts()

  get "/" do
    oban_name = Keyword.get(opts, :oban_name, Oban)
    state = state_param(conn.params)

    body =
      Ocelot.View.render(%{
        jobs: Ocelot.Jobs.list(oban_name, state: state),
        counts: Ocelot.Jobs.counts(oban_name),
        state: state,
        base_path: base_path(conn)
      })

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, body)
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  defp state_param(%{"state" => state}) when is_binary(state) do
    if state in Ocelot.Jobs.states(), do: state
  end

  defp state_param(_params), do: nil

  defp base_path(conn) do
    case Enum.join(conn.script_name, "/") do
      "" -> "/"
      path -> "/" <> path
    end
  end
end
