defmodule Ocelot.UI do
  @moduledoc """
  Renders the basic HTML shell for the Ocelot dashboard.
  """

  @doc """
  Returns the HTML markup for the dashboard's landing page.
  """
  def render do
    """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <title>Ocelot</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            margin: 0;
            padding: 2rem;
            background: #0f172a;
            color: #e2e8f0;
          }

          header {
            display: flex;
            align-items: center;
            gap: 0.75rem;
            margin-bottom: 1.5rem;
          }

          header h1 {
            font-size: 1.5rem;
            margin: 0;
          }

          .badge {
            background: #1e293b;
            color: #94a3b8;
            padding: 0.15rem 0.5rem;
            border-radius: 0.25rem;
            font-size: 0.75rem;
          }

          main {
            background: #1e293b;
            border-radius: 0.5rem;
            padding: 1.5rem;
          }
        </style>
      </head>
      <body>
        <header>
          <h1>Ocelot</h1>
          <span class="badge">Oban Web Lite</span>
        </header>
        <main>
          <p>Welcome to Ocelot, an unofficial Oban Web Lite dashboard.</p>
        </main>
      </body>
    </html>
    """
  end
end
