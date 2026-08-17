defmodule Ocelot.Router do
  @moduledoc """
  Basic Plug router that serves the Ocelot dashboard UI.
  """

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> Plug.Conn.put_resp_content_type("text/html")
    |> Plug.Conn.send_resp(200, Ocelot.UI.render())
  end

  match _ do
    Plug.Conn.send_resp(conn, 404, "Not found")
  end
end
