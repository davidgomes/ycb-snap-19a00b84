defmodule Ocelot.Router do
  @moduledoc """
  A minimal Plug router that serves the basic Ocelot dashboard UI.
  """

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, Ocelot.UI.render_dashboard())
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
