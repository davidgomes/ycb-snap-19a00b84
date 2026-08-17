defmodule FreeObanUiWeb.JobLiveTest do
  use FreeObanUiWeb.ConnCase

  import Phoenix.LiveViewTest

  defmodule SampleWorker do
    use Oban.Worker, queue: :default

    @impl Oban.Worker
    def perform(_job), do: :ok
  end

  test "lists jobs and filters by state", %{conn: conn} do
    {:ok, available} =
      SampleWorker.new(%{name: "available-job"})
      |> Oban.insert()

    {:ok, completed} = SampleWorker.new(%{name: "completed-job"}) |> Oban.insert()

    completed =
      completed
      |> Ecto.Changeset.change(%{state: "completed"})
      |> FreeObanUi.Repo.update!()

    {:ok, view, html} = live(conn, ~p"/jobs")

    assert html =~ "Oban Jobs"
    assert html =~ available.worker
    assert html =~ "available"
    assert html =~ "completed"

    view |> element("form") |> render_change(%{"state" => "completed"})
    html = render(view)
    assert html =~ Integer.to_string(completed.id)
    refute html =~ Integer.to_string(available.id)
  end

  test "shows job details", %{conn: conn} do
    {:ok, job} = SampleWorker.new(%{hello: "world"}) |> Oban.insert()

    {:ok, _view, html} = live(conn, ~p"/jobs/#{job.id}")

    assert html =~ "Job ##{job.id}"
    assert html =~ job.worker
    assert html =~ "available"
    assert html =~ "hello"
  end
end
