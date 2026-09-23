defmodule Ocelot.HTML do
  @moduledoc false

  require EEx

  @states Enum.map(Oban.Job.states(), &Atom.to_string/1)

  EEx.function_from_string(
    :defp,
    :layout,
    ~S"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title><%= h(title) %> · Ocelot</title>
      <style>
        :root { --fg: #1f2937; --muted: #6b7280; --border: #e5e7eb; --bg: #f9fafb; --accent: #4f46e5; }
        * { box-sizing: border-box; }
        body { margin: 0; font: 14px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif; color: var(--fg); background: var(--bg); }
        header { background: #111827; color: #fff; padding: 12px 24px; }
        header a { color: #fff; text-decoration: none; font-weight: 600; font-size: 16px; }
        main { max-width: 1200px; margin: 0 auto; padding: 24px; }
        h1 { font-size: 20px; margin: 0 0 16px; }
        h2 { font-size: 15px; margin: 24px 0 8px; }
        a { color: var(--accent); }
        .card { background: #fff; border: 1px solid var(--border); border-radius: 8px; overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; }
        th, td { text-align: left; padding: 8px 12px; border-bottom: 1px solid var(--border); vertical-align: top; }
        th { font-size: 12px; text-transform: uppercase; letter-spacing: .04em; color: var(--muted); background: var(--bg); }
        tr:last-child td { border-bottom: none; }
        code, pre { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 12px; }
        pre { margin: 0; padding: 12px; white-space: pre-wrap; word-break: break-word; }
        td pre { padding: 0; }
        .muted { color: var(--muted); }
        .truncate { max-width: 320px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .tabs { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 16px; }
        .tabs a { padding: 4px 10px; border: 1px solid var(--border); border-radius: 999px; background: #fff; color: var(--fg); text-decoration: none; }
        .tabs a.active { background: var(--accent); border-color: var(--accent); color: #fff; }
        .pager { display: flex; justify-content: space-between; align-items: center; margin-top: 12px; }
        .badge { display: inline-block; padding: 1px 8px; border-radius: 999px; font-size: 12px; background: #e5e7eb; }
        .badge.available, .badge.scheduled { background: #dbeafe; color: #1e40af; }
        .badge.executing { background: #fef3c7; color: #92400e; }
        .badge.retryable { background: #ffedd5; color: #9a3412; }
        .badge.completed { background: #dcfce7; color: #166534; }
        .badge.discarded { background: #fee2e2; color: #991b1b; }
        .badge.cancelled, .badge.suspended { background: #f3f4f6; color: #374151; }
        dl { display: grid; grid-template-columns: max-content 1fr; gap: 6px 24px; margin: 0; padding: 12px; }
        dt { color: var(--muted); }
        dd { margin: 0; }
      </style>
    </head>
    <body>
      <header><a href="<%= h(base) %>/jobs">Ocelot</a></header>
      <main><%= content %></main>
    </body>
    </html>
    """,
    [:title, :base, :content]
  )

  EEx.function_from_string(
    :defp,
    :job_list_content,
    ~S"""
    <h1>Jobs</h1>
    <nav class="tabs">
      <a href="<%= h(base) %>/jobs" class="<%= if is_nil(state), do: "active" %>">all (<%= total_count %>)</a>
      <%= for s <- states do %>
        <a href="<%= h(base) %>/jobs?state=<%= s %>" class="<%= if s == state, do: "active" %>"><%= s %> (<%= Map.get(counts, s, 0) %>)</a>
      <% end %>
    </nav>
    <div class="card">
      <table>
        <thead>
          <tr><th>ID</th><th>State</th><th>Queue</th><th>Worker</th><th>Attempt</th><th>Args</th><th>Inserted</th><th>Scheduled</th></tr>
        </thead>
        <tbody>
          <%= if jobs == [] do %>
            <tr><td colspan="8" class="muted">No jobs found.</td></tr>
          <% end %>
          <%= for job <- jobs do %>
            <tr>
              <td><a href="<%= h(base) %>/jobs/<%= job.id %>"><%= job.id %></a></td>
              <td><span class="badge <%= h(job.state) %>"><%= h(job.state) %></span></td>
              <td><%= h(job.queue) %></td>
              <td><code><%= h(job.worker) %></code></td>
              <td><%= job.attempt %>/<%= job.max_attempts %></td>
              <td class="truncate"><code><%= h(json(job.args)) %></code></td>
              <td><%= format_time(job.inserted_at) %></td>
              <td><%= format_time(job.scheduled_at) %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    <div class="pager">
      <span>
        <%= if page > 1 do %><a href="<%= h(page_path.(page - 1)) %>">&larr; Previous</a><% end %>
      </span>
      <span class="muted">Page <%= page %> of <%= total_pages %></span>
      <span>
        <%= if page < total_pages do %><a href="<%= h(page_path.(page + 1)) %>">Next &rarr;</a><% end %>
      </span>
    </div>
    """,
    [:jobs, :counts, :total_count, :states, :state, :page, :total_pages, :page_path, :base]
  )

  EEx.function_from_string(
    :defp,
    :job_detail_content,
    ~S"""
    <p><a href="<%= h(base) %>/jobs">&larr; All jobs</a></p>
    <h1>Job <%= job.id %> <span class="badge <%= h(job.state) %>"><%= h(job.state) %></span></h1>
    <div class="card">
      <dl>
        <dt>Worker</dt><dd><code><%= h(job.worker) %></code></dd>
        <dt>Queue</dt><dd><%= h(job.queue) %></dd>
        <dt>Priority</dt><dd><%= h(job.priority) %></dd>
        <dt>Attempt</dt><dd><%= job.attempt %>/<%= job.max_attempts %></dd>
        <dt>Tags</dt><dd><%= h(Enum.join(job.tags || [], ", ")) %></dd>
        <dt>Attempted by</dt><dd><%= h(Enum.join(job.attempted_by || [], ", ")) %></dd>
        <%= for {label, value} <- timestamps do %>
          <dt><%= label %></dt><dd><%= format_time(value) %></dd>
        <% end %>
      </dl>
    </div>
    <h2>Args</h2>
    <div class="card"><pre><%= h(json(job.args, pretty: true)) %></pre></div>
    <h2>Meta</h2>
    <div class="card"><pre><%= h(json(job.meta, pretty: true)) %></pre></div>
    <h2>Errors</h2>
    <div class="card">
      <%= if job.errors in [nil, []] do %>
        <p class="muted" style="padding: 0 12px">No errors.</p>
      <% else %>
        <table>
          <thead><tr><th>Attempt</th><th>At</th><th>Error</th></tr></thead>
          <tbody>
            <%= for error <- Enum.reverse(job.errors) do %>
              <tr>
                <td><%= h(error["attempt"]) %></td>
                <td><%= h(error["at"]) %></td>
                <td><pre><%= h(error["error"]) %></pre></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% end %>
    </div>
    """,
    [:job, :timestamps, :base]
  )

  def job_list(jobs, counts, state, page, total_pages, base) do
    page_path = fn page ->
      query = URI.encode_query(Enum.reject([state: state, page: page], &is_nil(elem(&1, 1))))
      "#{base}/jobs?#{query}"
    end

    content =
      job_list_content(
        jobs,
        counts,
        counts |> Map.values() |> Enum.sum(),
        @states,
        state,
        page,
        total_pages,
        page_path,
        base
      )

    layout("Jobs", base, content)
  end

  def job_detail(%Oban.Job{} = job, base) do
    timestamps = [
      {"Inserted", job.inserted_at},
      {"Scheduled", job.scheduled_at},
      {"Attempted", job.attempted_at},
      {"Completed", job.completed_at},
      {"Discarded", job.discarded_at},
      {"Cancelled", job.cancelled_at}
    ]

    layout("Job #{job.id}", base, job_detail_content(job, timestamps, base))
  end

  def not_found(base) do
    layout(
      "Not found",
      base,
      ~s(<h1>Not found</h1><p><a href="#{h(base)}/jobs">Back to jobs</a></p>)
    )
  end

  defp h(nil), do: ""
  defp h(value), do: value |> to_string() |> Plug.HTML.html_escape()

  defp json(value, opts \\ []), do: Jason.encode!(value, opts)

  defp format_time(nil), do: ~s(<span class="muted">&mdash;</span>)
  defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
end
