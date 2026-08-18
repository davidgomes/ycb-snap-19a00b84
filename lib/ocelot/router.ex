defmodule Ocelot.Router do
  @moduledoc """
  The basic HTTP router that serves the Ocelot dashboard UI.
  """

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, index_html())
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  defp index_html do
    """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Ocelot</title>
        <style>
          :root {
            color-scheme: dark;
          }

          body {
            margin: 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: #0f172a;
            color: #e2e8f0;
          }

          header {
            padding: 1.5rem 2rem;
            background: #1e293b;
            border-bottom: 1px solid #334155;
          }

          header h1 {
            margin: 0;
            font-size: 1.5rem;
          }

          main {
            padding: 2rem;
          }

          .card {
            background: #1e293b;
            border: 1px solid #334155;
            border-radius: 0.5rem;
            padding: 1.5rem;
            max-width: 32rem;
          }
        </style>
      </head>
      <body>
        <header>
          <h1>Ocelot</h1>
        </header>
        <main>
          <div class="card">
            <p>Welcome to Ocelot, the unofficial Oban Web Lite Dashboard.</p>
          </div>
        </main>
      </body>
    </html>
    """
  end
end
