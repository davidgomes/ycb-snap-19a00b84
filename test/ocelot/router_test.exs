defmodule Ocelot.RouterTest do
  use ExUnit.Case, async: false

  import Plug.Test

  alias Ocelot.Test.Repo

  defmodule Worker do
    use Oban.Worker

    @impl Oban.Worker
    def perform(_job), do: :ok
  end

  defmodule MountRouter do
    use Plug.Router

    plug :match
    plug :dispatch

    forward "/oban", to: Ocelot.Router
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  describe "jobs list" do
    test "lists jobs with state and queue counts" do
      insert!(%{"n" => 1})
      insert!(%{"n" => 2}, queue: "mailers")
      insert!(%{"n" => 3}, state: "completed", completed_at: DateTime.utc_now())

      conn = request("/")
      body = conn.resp_body

      assert conn.status == 200
      assert ["text/html; charset=utf-8"] = Plug.Conn.get_resp_header(conn, "content-type")
      assert body =~ "All jobs"
      assert rows(body) == 3
      assert count(body, "all") == 3
      assert count(body, "available") == 2
      assert count(body, "completed") == 1
      assert count(body, "discarded") == 0
      assert count(body, "default") == 2
      assert count(body, "mailers") == 1
    end

    test "counts states within the selected queue and queues within the selected state" do
      insert!(%{"n" => 1})
      insert!(%{"n" => 2}, queue: "mailers")
      insert!(%{"n" => 3}, queue: "mailers", state: "completed", completed_at: DateTime.utc_now())

      by_queue = request("/?queue=mailers").resp_body
      by_state = request("/?state=completed").resp_body

      assert count(by_queue, "available") == 1
      assert count(by_queue, "completed") == 1
      assert count(by_state, "mailers") == 1
      refute by_state =~ ~s(<span class="label">default</span>)
    end

    test "filters by state" do
      available = insert!(%{"n" => 1})
      completed = insert!(%{"n" => 2}, state: "completed", completed_at: DateTime.utc_now())

      body = request("/?state=completed").resp_body

      assert body =~ "Completed jobs"
      assert body =~ ~s(href="/jobs/#{completed.id}")
      refute body =~ ~s(href="/jobs/#{available.id}")
    end

    test "filters by queue" do
      default = insert!(%{"n" => 1})
      mailer = insert!(%{"n" => 2}, queue: "mailers")

      body = request("/?queue=mailers").resp_body

      assert body =~ "All jobs in mailers"
      assert body =~ ~s(href="/jobs/#{mailer.id}")
      refute body =~ ~s(href="/jobs/#{default.id}")
    end

    test "ignores unknown states and invalid pages" do
      insert!(%{"n" => 1})

      body = request("/?state=bogus&page=-1").resp_body

      assert body =~ "All jobs"
      assert body =~ "Page 1"
      assert rows(body) == 1
    end

    test "paginates jobs" do
      for n <- 1..(Ocelot.Jobs.per_page() + 1), do: insert!(%{"n" => n})

      first = request("/").resp_body
      second = request("/?page=2").resp_body

      assert rows(first) == Ocelot.Jobs.per_page()
      assert first =~ ~s(href="/?page=2")
      assert rows(second) == 1
      assert second =~ ~s(<a href="/">← Previous</a>)
      refute second =~ ~s(href="/?page=3")
    end

    test "shows an empty state" do
      assert request("/").resp_body =~ "No jobs found"
    end
  end

  describe "job details" do
    test "shows args, meta and errors" do
      job =
        insert!(%{"email" => "user@example.com"},
          state: "retryable",
          attempt: 1,
          meta: %{"source" => "test"},
          tags: ["billing"],
          errors: [%{at: DateTime.utc_now(), attempt: 1, error: "** (RuntimeError) boom"}]
        )

      conn = request("/jobs/#{job.id}")

      assert conn.status == 200
      assert conn.resp_body =~ "Ocelot.RouterTest.Worker"
      assert conn.resp_body =~ "retryable"
      assert conn.resp_body =~ "&quot;email&quot;: &quot;user@example.com&quot;"
      assert conn.resp_body =~ "&quot;source&quot;: &quot;test&quot;"
      assert conn.resp_body =~ ~s(<span class="tag">billing</span>)
      assert conn.resp_body =~ "Errors (1)"
      assert conn.resp_body =~ "** (RuntimeError) boom"
    end

    test "returns 404 for missing or invalid jobs" do
      for path <- ["/jobs/123456", "/jobs/abc", "/jobs/0", "/jobs/99999999999999999999999"] do
        conn = request(path)

        assert conn.status == 404
        assert conn.resp_body =~ "Not found"
      end
    end
  end

  test "returns 404 for unknown paths" do
    assert request("/unknown").status == 404
  end

  test "escapes job content" do
    job = insert!(%{"name" => "<script>alert('xss')</script>"}, tags: ["<b>tag</b>"])

    list = request("/").resp_body
    detail = request("/jobs/#{job.id}").resp_body

    for body <- [list, detail] do
      refute body =~ "<script>"
      assert body =~ "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"
    end

    assert detail =~ "&lt;b&gt;tag&lt;/b&gt;"
  end

  test "builds links relative to the mount path" do
    job = insert!(%{"n" => 1})

    list = conn(:get, "/oban") |> MountRouter.call(MountRouter.init([]))
    detail = conn(:get, "/oban/jobs/#{job.id}") |> MountRouter.call(MountRouter.init([]))

    assert list.status == 200
    assert list.resp_body =~ ~s(href="/oban/jobs/#{job.id}")
    assert list.resp_body =~ ~s(href="/oban?state=available")
    assert detail.status == 200
    assert detail.resp_body =~ ~s(<a href="/oban">Jobs</a>)
  end

  test "inspects the configured Oban instance" do
    start_supervised!(
      {Oban, name: Ocelot.OtherOban, engine: Oban.Engines.Lite, repo: Repo, testing: :manual}
    )

    body = request("/", oban: Ocelot.OtherOban).resp_body

    assert body =~ "Ocelot.OtherOban"
  end

  defp request(path, opts \\ []) do
    conn(:get, path) |> Ocelot.Router.call(Ocelot.Router.init(opts))
  end

  defp insert!(args, opts \\ []) do
    args |> Worker.new(opts) |> Oban.insert!()
  end

  defp rows(body), do: length(Regex.scan(~r/class="worker"/, body))

  defp count(body, label) do
    [_, count] = Regex.run(~r/"label">#{label}<\/span>\s*<span class="count">(\d+)</, body)
    String.to_integer(count)
  end
end
