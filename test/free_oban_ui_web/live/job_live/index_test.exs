defmodule FreeObanUiWeb.JobLive.IndexTest do
  use FreeObanUiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias FreeObanUi.Repo

  defmodule FakeWorker do
    use Oban.Worker, queue: :default

    @impl Oban.Worker
    def perform(_job), do: :ok
  end

  defp insert_job!(opts) do
    opts
    |> Keyword.new()
    |> Keyword.put_new(:worker, FakeWorker)
    |> then(&Oban.Job.new(%{}, &1))
    |> Repo.insert!()
  end

  test "lists jobs with their state and queue", %{conn: conn} do
    insert_job!(queue: "default", state: "available")
    insert_job!(queue: "mailers", state: "completed")

    {:ok, view, html} = live(conn, ~p"/jobs")

    assert html =~ "Oban Jobs"
    assert has_element?(view, "#jobs")
    assert render(view) =~ "default"
    assert render(view) =~ "mailers"
  end

  test "filters jobs by state", %{conn: conn} do
    insert_job!(state: "available")
    insert_job!(state: "completed")

    {:ok, view, _html} = live(conn, ~p"/jobs")

    view
    |> form("form", %{"state" => "completed", "queue" => ""})
    |> render_change()

    html = render(view)
    assert html =~ "completed"
    refute html =~ "No jobs found"
  end

  test "retrying a discarded job makes it available again", %{conn: conn} do
    job = insert_job!(state: "discarded", max_attempts: 1, attempt: 1)

    {:ok, view, _html} = live(conn, ~p"/jobs")

    view
    |> element("button[phx-click='retry'][phx-value-id='#{job.id}']")
    |> render_click()

    assert Repo.get!(Oban.Job, job.id).state == "available"
    assert render(view) =~ "Job scheduled for retry."
  end

  test "deleting a job removes it from the list", %{conn: conn} do
    job = insert_job!(state: "completed")

    {:ok, view, _html} = live(conn, ~p"/jobs")

    view
    |> element("button[phx-click='delete'][phx-value-id='#{job.id}']")
    |> render_click()

    assert_raise Ecto.NoResultsError, fn -> Repo.get!(Oban.Job, job.id) end
    refute has_element?(view, "button[phx-value-id='#{job.id}']")
  end
end
