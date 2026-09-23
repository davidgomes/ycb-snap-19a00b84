defmodule FreeObanUiWeb.ObanLiveTest do
  use FreeObanUiWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias FreeObanUi.Repo

  test "lists jobs and filters by state and queue", %{conn: conn} do
    scheduled = insert_job(%{state: "scheduled", queue: "default", worker: "MyApp.Scheduled"})
    _completed = insert_job(%{state: "completed", queue: "mailers", worker: "MyApp.Mailer"})

    {:ok, view, html} = live(conn, ~p"/oban")

    assert html =~ "Oban Jobs"
    assert html =~ "MyApp.Scheduled"
    assert html =~ "MyApp.Mailer"
    assert html =~ "scheduled"
    assert html =~ "available (0)"

    html = view |> element("a", "scheduled") |> render_click()
    assert html =~ "MyApp.Scheduled"
    refute html =~ "MyApp.Mailer"

    html = view |> element("a", "Clear") |> render_click()
    assert html =~ "MyApp.Scheduled"
    assert html =~ "MyApp.Mailer"

    html = view |> element("a", "mailers") |> render_click()
    assert html =~ "MyApp.Mailer"
    refute html =~ "MyApp.Scheduled"

    {:ok, _view, html} = live(conn, ~p"/oban/#{scheduled.id}")
    assert html =~ "Job ##{scheduled.id}"
    assert html =~ "MyApp.Scheduled"
    assert html =~ "Run"
    assert html =~ "Cancel"
  end

  test "runs, cancels, and deletes a job", %{conn: conn} do
    job = insert_job(%{state: "scheduled", queue: "default", worker: "MyApp.Scheduled"})

    {:ok, view, _html} = live(conn, ~p"/oban/#{job.id}")

    html = view |> element("button", "Run") |> render_click()
    assert html =~ "available"

    reloaded = Repo.get!(Oban.Job, job.id)
    assert reloaded.state == "available"

    html = view |> element("button", "Cancel") |> render_click()
    assert html =~ "cancelled"
    assert Repo.get!(Oban.Job, job.id).state == "cancelled"

    view |> element("button", "Delete") |> render_click()
    refute Repo.get(Oban.Job, job.id)
  end

  test "bulk deletes selected jobs", %{conn: conn} do
    job = insert_job(%{state: "completed", queue: "default", worker: "MyApp.Done"})

    {:ok, view, _html} = live(conn, ~p"/oban?state=completed")

    view |> element("#job-#{job.id}") |> render_click()
    view |> element("button", "Delete") |> render_click()

    refute Repo.get(Oban.Job, job.id)
  end

  defp insert_job(attrs) do
    now = DateTime.utc_now()

    %Oban.Job{}
    |> Ecto.Changeset.change(
      Map.merge(
        %{
          state: "available",
          queue: "default",
          worker: "MyApp.Worker",
          args: %{"hello" => "world"},
          meta: %{},
          tags: [],
          errors: [],
          attempt: 0,
          max_attempts: 20,
          priority: 0,
          scheduled_at: now,
          inserted_at: now
        },
        attrs
      )
    )
    |> Repo.insert!()
  end
end
