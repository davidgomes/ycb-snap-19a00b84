defmodule FreeObanUiWeb.ObanLiveTest do
  use FreeObanUiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias FreeObanUi.Repo
  alias FreeObanUi.Workers.ExampleWorker

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

  test "lists jobs across queues", %{conn: conn} do
    default_job = insert_job!(queue: "default", state: "available")
    mailer_job = insert_job!(queue: "mailers", state: "completed")

    {:ok, view, html} = live(conn, ~p"/oban")

    assert html =~ "Oban Jobs"
    assert has_element?(view, "#jobs")
    assert render(view) =~ "job-#{default_job.id}"
    assert render(view) =~ "job-#{mailer_job.id}"
    assert render(view) =~ "default"
    assert render(view) =~ "mailers"
  end

  test "filters jobs by state", %{conn: conn} do
    available_job = insert_job!(state: "available")
    completed_job = insert_job!(state: "completed")

    {:ok, view, _html} = live(conn, ~p"/oban")

    html =
      view
      |> form("form", %{"state" => "completed", "queue" => "all"})
      |> render_change()

    assert html =~ "job-#{completed_job.id}"
    refute html =~ "job-#{available_job.id}"
  end

  test "filters jobs by queue", %{conn: conn} do
    default_job = insert_job!(queue: "default")
    mailer_job = insert_job!(queue: "mailers")

    {:ok, view, _html} = live(conn, ~p"/oban")

    html =
      view
      |> form("form", %{"state" => "all", "queue" => "mailers"})
      |> render_change()

    assert html =~ "job-#{mailer_job.id}"
    refute html =~ "job-#{default_job.id}"
  end

  test "cancelling an available job marks it as cancelled", %{conn: conn} do
    job = insert_job!(state: "available")

    {:ok, view, _html} = live(conn, ~p"/oban")

    view
    |> element("button[phx-click='cancel'][phx-value-id='#{job.id}']")
    |> render_click()

    assert Repo.get!(Oban.Job, job.id).state == "cancelled"
    assert render(view) =~ "Job cancelled."
  end

  test "retrying a discarded job makes it available again", %{conn: conn} do
    job = insert_job!(state: "discarded", max_attempts: 1, attempt: 1)

    {:ok, view, _html} = live(conn, ~p"/oban")

    view
    |> element("button[phx-click='retry'][phx-value-id='#{job.id}']")
    |> render_click()

    assert Repo.get!(Oban.Job, job.id).state == "available"
    assert render(view) =~ "Job scheduled for retry."
  end

  test "deleting a job removes it from the list", %{conn: conn} do
    job = insert_job!(state: "completed")

    {:ok, view, _html} = live(conn, ~p"/oban")

    view
    |> element("button[phx-click='delete'][phx-value-id='#{job.id}']")
    |> render_click()

    assert_raise Ecto.NoResultsError, fn -> Repo.get!(Oban.Job, job.id) end
    refute has_element?(view, "button[phx-value-id='#{job.id}']")
    assert render(view) =~ "Job deleted."
  end
end
