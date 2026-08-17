defmodule FreeObanUiWeb.ObanLiveTest do
  use FreeObanUiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias FreeObanUi.Workers.ExampleWorker

  defp insert_job!(args, opts \\ []) do
    args |> ExampleWorker.new(opts) |> Oban.insert!()
  end

  test "lists jobs across queues", %{conn: conn} do
    default_job = insert_job!(%{id: 1}, queue: :default)
    mailer_job = insert_job!(%{id: 2}, queue: :mailers)

    {:ok, _view, html} = live(conn, ~p"/oban")

    assert html =~ "Oban Jobs"
    assert html =~ "job-#{default_job.id}"
    assert html =~ "job-#{mailer_job.id}"
  end

  test "filters jobs by queue", %{conn: conn} do
    default_job = insert_job!(%{id: 1}, queue: :default)
    mailer_job = insert_job!(%{id: 2}, queue: :mailers)

    {:ok, view, _html} = live(conn, ~p"/oban")

    html =
      view
      |> form("form", %{"state" => "all", "queue" => "mailers"})
      |> render_change()

    assert html =~ "job-#{mailer_job.id}"
    refute html =~ "job-#{default_job.id}"
  end

  test "cancelling an available job marks it as cancelled", %{conn: conn} do
    job = insert_job!(%{id: 1})

    {:ok, view, _html} = live(conn, ~p"/oban")

    html =
      view
      |> element("#job-#{job.id} button", "Cancel")
      |> render_click()

    assert html =~ "cancelled"
  end
end
