defmodule Ocelot.UI do
  @moduledoc """
  Renders the basic HTML shell for the Ocelot dashboard.
  """

  @doc """
  Returns the HTML markup for the dashboard page.
  """
  def render_dashboard do
    """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <title>Ocelot</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            background: #f5f5f5;
            color: #1a1a1a;
            margin: 0;
            padding: 0;
          }

          header {
            background: #1a1a1a;
            color: #fff;
            padding: 1rem 2rem;
          }

          header h1 {
            margin: 0;
            font-size: 1.25rem;
          }

          main {
            padding: 2rem;
          }

          .card {
            background: #fff;
            border-radius: 8px;
            padding: 1.5rem;
            box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
          }
        </style>
      </head>
      <body>
        <header>
          <h1>Ocelot</h1>
        </header>
        <main>
          <div class="card">
            <p>Welcome to Ocelot, an unofficial Oban Web Lite dashboard.</p>
          </div>
        </main>
      </body>
    </html>
    """
  end
end
