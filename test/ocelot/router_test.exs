defmodule Ocelot.RouterTest do
  use ExUnit.Case, async: false

  import Plug.Test

  alias Ocelot.TestRepo

  @opts Ocelot.Router.init(oban: Ocelot.TestOban)

  defmodule MountedRouter do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    forward("/oban", to: Ocelot.Router, init_opts: [oban: Ocelot.TestOban])
  end

  setup do
    TestRepo.delete_all(Oban.Job)
    :ok
  end

  describe "init/1" do
    test "defaults to the Oban instance named Oban" do
      assert Ocelot.Router.init([]) == [oban: Oban]
    end

    test "rejects unknown options" do
      assert_raise ArgumentError, fn -> Ocelot.Router.init(repo: Ocelot.TestRepo) end
    end
  end

  describe "GET /" do
    test "lists jobs newest first" do
      insert_job!(%{"email" => "old@example.com"}, worker: "MyApp.OldWorker")
      insert_job!(%{"email" => "new@example.com"}, worker: "MyApp.NewWorker")

      conn = request("/")

      assert conn.status == 200
      assert Plug.Conn.get_resp_header(conn, "content-type") == ["text/html; charset=utf-8"]
      assert conn.resp_body =~ "old@example.com"

      assert position(conn.resp_body, "MyApp.NewWorker") <
               position(conn.resp_body, "MyApp.OldWorker")
    end

    test "shows job counts per state and per queue" do
      insert_job!(%{}, queue: "mailers")
      insert_job!(%{}, queue: "mailers", state: "completed")
      insert_job!(%{}, queue: "default", state: "completed")

      body = request("/").resp_body

      assert body =~ ~r{completed <span class="count">2</span>}
      assert body =~ ~r{available <span class="count">1</span>}
      assert body =~ ~r{<span>mailers</span>\s*<span class="count">2</span>}
      assert body =~ ~r{<span>default</span>\s*<span class="count">1</span>}
    end

    test "filters by state" do
      insert_job!(%{}, worker: "MyApp.Pending")
      insert_job!(%{}, worker: "MyApp.Done", state: "completed")

      body = request("/?state=completed").resp_body

      assert body =~ "MyApp.Done"
      refute body =~ "MyApp.Pending"
    end

    test "ignores unknown states" do
      insert_job!(%{}, worker: "MyApp.Pending")

      assert request("/?state=bogus").resp_body =~ "MyApp.Pending"
    end

    test "filters by queue and scopes state counts to it" do
      insert_job!(%{}, worker: "MyApp.Mailer", queue: "mailers")
      insert_job!(%{}, worker: "MyApp.Default", queue: "default", state: "completed")

      body = request("/?queue=mailers").resp_body

      assert body =~ "MyApp.Mailer"
      refute body =~ "MyApp.Default"
      assert body =~ ~r{completed <span class="count">0</span>}
    end

    test "paginates" do
      for n <- 1..26,
          do: insert_job!(%{}, worker: "MyApp.Worker#{String.pad_leading("#{n}", 2, "0")}")

      first_page = request("/").resp_body

      assert first_page =~ "MyApp.Worker26"
      refute first_page =~ "MyApp.Worker01"
      assert first_page =~ ~s(href="/?page=2")
      refute first_page =~ "Previous"

      second_page = request("/?page=2").resp_body

      assert second_page =~ "MyApp.Worker01"
      refute second_page =~ "MyApp.Worker02"
      assert second_page =~ ~s(href="/")
      refute second_page =~ "Next"
    end

    test "shows an empty state" do
      assert request("/").resp_body =~ "No jobs found."
    end
  end

  describe "GET /jobs/:id" do
    test "shows the job details" do
      job =
        insert_job!(%{"user_id" => 42},
          worker: "MyApp.Mailer",
          queue: "mailers",
          state: "retryable",
          attempt: 1,
          tags: ["welcome", "email"],
          meta: %{"source" => "signup"},
          errors: [
            %{"attempt" => 1, "at" => "2026-09-23T15:00:00Z", "error" => "** (RuntimeError) boom"}
          ]
        )

      conn = request("/jobs/#{job.id}")

      assert conn.status == 200
      assert conn.resp_body =~ "MyApp.Mailer"
      assert conn.resp_body =~ "retryable"
      assert conn.resp_body =~ "1 of 20"
      assert conn.resp_body =~ "welcome, email"
      assert conn.resp_body =~ "&quot;user_id&quot;: 42"
      assert conn.resp_body =~ "&quot;source&quot;: &quot;signup&quot;"
      assert conn.resp_body =~ "Errors (1)"
      assert conn.resp_body =~ "** (RuntimeError) boom"
      assert conn.resp_body =~ "2026-09-23 15:00:00 UTC"
    end

    test "responds with 404 for unknown jobs" do
      assert request("/jobs/123456").status == 404
      assert request("/jobs/abc").status == 404
    end
  end

  test "responds with 404 for unknown paths" do
    conn = request("/nope")

    assert conn.status == 404
    assert conn.resp_body =~ "Page not found"
  end

  test "escapes job data" do
    payload = "<script>alert(1)</script>"
    job = insert_job!(%{"html" => payload}, queue: payload, errors: [%{"error" => payload}])

    for path <- ["/", "/jobs/#{job.id}"] do
      body = request(path).resp_body

      refute body =~ payload
      assert body =~ "&lt;script&gt;alert(1)&lt;/script&gt;"
    end
  end

  test "builds links relative to the mount path" do
    job = insert_job!(%{}, queue: "mailers")

    list = request("/oban", MountedRouter)

    assert list.status == 200
    assert list.resp_body =~ ~s(href="/oban/jobs/#{job.id}")
    assert list.resp_body =~ ~s(href="/oban?state=completed")
    assert list.resp_body =~ ~s(href="/oban?queue=mailers")

    detail = request("/oban/jobs/#{job.id}", MountedRouter)

    assert detail.status == 200
    assert detail.resp_body =~ ~s(href="/oban")
  end

  defp insert_job!(args, opts) do
    job = Oban.Job.new(args, Keyword.put_new(opts, :worker, "MyApp.Worker"))

    Oban.insert!(Ocelot.TestOban, job)
  end

  defp request(path, plug \\ Ocelot.Router) do
    opts = if plug == Ocelot.Router, do: @opts, else: plug.init([])

    :get
    |> conn(path)
    |> plug.call(opts)
  end

  defp position(body, text) do
    {index, _length} = :binary.match(body, text)
    index
  end
end
