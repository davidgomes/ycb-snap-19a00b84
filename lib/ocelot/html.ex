defmodule Ocelot.HTML do
  @moduledoc false

  require EEx

  @style """
  body { font-family: system-ui, sans-serif; margin: 0; color: #1f2937; background: #f9fafb; }
  header { background: #111827; color: #f9fafb; padding: 0.75rem 1.5rem; }
  header a { color: inherit; text-decoration: none; font-weight: 600; font-size: 1.25rem; }
  main { padding: 1.5rem; }
  a { color: #2563eb; }
  nav.states { display: flex; flex-wrap: wrap; gap: 0.5rem; margin-bottom: 1rem; }
  nav.states a { padding: 0.25rem 0.75rem; border-radius: 9999px; background: #e5e7eb; color: #1f2937; text-decoration: none; }
  nav.states a.active { background: #2563eb; color: #fff; }
  table { width: 100%; border-collapse: collapse; background: #fff; }
  th, td { text-align: left; padding: 0.5rem; border-bottom: 1px solid #e5e7eb; vertical-align: top; }
  th { background: #f3f4f6; font-weight: 600; }
  code, pre { font-family: ui-monospace, monospace; font-size: 0.875rem; }
  pre { background: #fff; border: 1px solid #e5e7eb; padding: 0.75rem; overflow-x: auto; }
  .pagination { display: flex; gap: 1rem; align-items: center; margin-top: 1rem; }
  .state { font-weight: 600; }
  .empty { color: #6b7280; }
  dl { display: grid; grid-template-columns: max-content 1fr; gap: 0.25rem 1rem; }
  dt { font-weight: 600; }
  dd { margin: 0; }
  """

  EEx.function_from_string(
    :defp,
    :layout,
    ~S"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title><%= e(title) %> · Ocelot</title>
      <style><%= style() %></style>
    </head>
    <body>
      <header><a href="<%= e(path(base, "/")) %>">Ocelot</a></header>
      <main><%= content %></main>
    </body>
    </html>
    """,
    [:title, :base, :content]
  )

  EEx.function_from_string(
    :defp,
    :index_content,
    ~S"""
    <nav class="states">
      <a href="<%= e(path(base, "/")) %>"<%= if is_nil(state), do: ~s( class="active") %>>all (<%= Enum.sum(Map.values(counts)) %>)</a>
    <%= for s <- states() do %>
      <a href="<%= e(path(base, "/", state: s)) %>"<%= if s == state, do: ~s( class="active") %>><%= e(s) %> (<%= Map.get(counts, s, 0) %>)</a>
    <% end %>
    </nav>
    <%= if jobs == [] do %>
    <p class="empty">No jobs found.</p>
    <% else %>
    <table>
      <thead>
        <tr><th>ID</th><th>Worker</th><th>Queue</th><th>State</th><th>Attempt</th><th>Args</th><th>Inserted at</th></tr>
      </thead>
      <tbody>
      <%= for job <- jobs do %>
        <tr>
          <td><a href="<%= e(path(base, "/jobs/#{job.id}")) %>"><%= job.id %></a></td>
          <td><%= e(job.worker) %></td>
          <td><%= e(job.queue) %></td>
          <td class="state"><%= e(job.state) %></td>
          <td><%= job.attempt %>/<%= job.max_attempts %></td>
          <td><code><%= e(truncate(json(job.args), 80)) %></code></td>
          <td><%= e(timestamp(job.inserted_at)) %></td>
        </tr>
      <% end %>
      </tbody>
    </table>
    <% end %>
    <div class="pagination">
    <%= if page > 1 do %>
      <a href="<%= e(path(base, "/", state: state, page: page - 1)) %>">&larr; Previous</a>
    <% end %>
      <span>Page <%= page %> of <%= total_pages %></span>
    <%= if page < total_pages do %>
      <a href="<%= e(path(base, "/", state: state, page: page + 1)) %>">Next &rarr;</a>
    <% end %>
    </div>
    """,
    [:jobs, :counts, :state, :page, :total_pages, :base]
  )

  EEx.function_from_string(
    :defp,
    :job_content,
    ~S"""
    <p><a href="<%= e(path(base, "/")) %>">&larr; All jobs</a></p>
    <h1>Job <%= job.id %></h1>
    <dl>
      <dt>Worker</dt><dd><%= e(job.worker) %></dd>
      <dt>Queue</dt><dd><%= e(job.queue) %></dd>
      <dt>State</dt><dd class="state"><%= e(job.state) %></dd>
      <dt>Attempt</dt><dd><%= job.attempt %>/<%= job.max_attempts %></dd>
      <dt>Priority</dt><dd><%= e(job.priority) %></dd>
      <dt>Tags</dt><dd><%= e(Enum.join(job.tags || [], ", ")) %></dd>
      <dt>Attempted by</dt><dd><%= e(Enum.join(job.attempted_by || [], ", ")) %></dd>
      <dt>Inserted at</dt><dd><%= e(timestamp(job.inserted_at)) %></dd>
      <dt>Scheduled at</dt><dd><%= e(timestamp(job.scheduled_at)) %></dd>
      <dt>Attempted at</dt><dd><%= e(timestamp(job.attempted_at)) %></dd>
      <dt>Completed at</dt><dd><%= e(timestamp(job.completed_at)) %></dd>
      <dt>Cancelled at</dt><dd><%= e(timestamp(job.cancelled_at)) %></dd>
      <dt>Discarded at</dt><dd><%= e(timestamp(job.discarded_at)) %></dd>
    </dl>
    <h2>Args</h2>
    <pre><%= e(json(job.args, pretty: true)) %></pre>
    <h2>Meta</h2>
    <pre><%= e(json(job.meta, pretty: true)) %></pre>
    <h2>Errors</h2>
    <%= if job.errors in [nil, []] do %>
    <p class="empty">No errors.</p>
    <% else %>
    <%= for error <- job.errors do %>
    <p>Attempt <%= e(error["attempt"]) %> at <%= e(error["at"]) %></p>
    <pre><%= e(error["error"]) %></pre>
    <% end %>
    <% end %>
    """,
    [:job, :base]
  )

  def index(jobs, counts, state, page, total_pages, base) do
    title = if state, do: "#{state} jobs", else: "Jobs"
    layout(title, base, index_content(jobs, counts, state, page, total_pages, base))
  end

  def job(job, base) do
    layout("Job #{job.id}", base, job_content(job, base))
  end

  def not_found(base) do
    layout("Not found", base, "<h1>Not found</h1>")
  end

  def states, do: Enum.map(Oban.Job.states(), &Atom.to_string/1)

  defp style, do: @style

  defp path(base, path, params \\ []) do
    query =
      params
      |> Enum.reject(fn {key, value} -> is_nil(value) or (key == :page and value == 1) end)
      |> URI.encode_query()

    if query == "", do: base <> path, else: base <> path <> "?" <> query
  end

  defp e(nil), do: ""
  defp e(value), do: value |> to_string() |> Plug.HTML.html_escape()

  defp json(value, opts \\ []) do
    case Jason.encode(value, opts) do
      {:ok, encoded} -> encoded
      {:error, _} -> inspect(value, pretty: true)
    end
  end

  defp timestamp(nil), do: nil

  defp timestamp(%DateTime{} = datetime) do
    datetime |> DateTime.truncate(:second) |> DateTime.to_iso8601()
  end

  defp truncate(string, max) do
    if String.length(string) > max, do: String.slice(string, 0, max) <> "…", else: string
  end
end
