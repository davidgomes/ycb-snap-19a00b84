defmodule Ocelot.Router do
  @moduledoc """
  Minimal Plug router that serves the Ocelot dashboard UI.
  """

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, Ocelot.Page.dashboard())
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
