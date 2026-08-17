defmodule Ocelot.Page do
  @moduledoc """
  Renders the HTML markup for the Ocelot dashboard UI.
  """

  @doc """
  Renders the dashboard page as a complete HTML document.
  """
  def dashboard do
    """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Ocelot</title>
        <style>#{stylesheet()}</style>
      </head>
      <body>
        <header class="topbar">
          <span class="brand">Ocelot</span>
          <span class="tagline">Oban Web Lite Dashboard</span>
        </header>
        <main>
          <section class="card">
            <h1>Queues</h1>
            <p class="empty">No queues configured yet.</p>
          </section>
          <section class="card">
            <h1>Jobs</h1>
            <p class="empty">No jobs to display yet.</p>
          </section>
        </main>
      </body>
    </html>
    """
  end

  defp stylesheet do
    """
    :root {
      color-scheme: dark;
      --bg: #14161a;
      --surface: #1d2025;
      --border: #2a2e35;
      --text: #e7e9ec;
      --muted: #8b909a;
      --accent: #f2a541;
    }

    * {
      box-sizing: border-box;
    }

    body {
      margin: 0;
      background: var(--bg);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
    }

    .topbar {
      display: flex;
      align-items: baseline;
      gap: 0.75rem;
      padding: 1rem 1.5rem;
      border-bottom: 1px solid var(--border);
    }

    .brand {
      font-size: 1.25rem;
      font-weight: 700;
      color: var(--accent);
    }

    .tagline {
      color: var(--muted);
      font-size: 0.9rem;
    }

    main {
      padding: 1.5rem;
      display: grid;
      gap: 1rem;
    }

    .card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 1rem 1.25rem;
    }

    .card h1 {
      margin: 0 0 0.5rem;
      font-size: 1rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: var(--muted);
    }

    .empty {
      margin: 0;
      color: var(--muted);
    }
    """
  end
end
