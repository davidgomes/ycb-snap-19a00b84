defmodule FreeObanUiWeb.ObanLiveTest do
  use FreeObanUiWeb.ConnCase

  import Phoenix.LiveViewTest

  alias FreeObanUi.Repo

  setup do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    completed =
      insert_job!(%{
        state: "completed",
        queue: "default",
        worker: "FreeObanUi.Workers.Completed",
        args: %{"id" => 1},
        completed_at: now,
        inserted_at: now,
        scheduled_at: now
      })

    scheduled =
      insert_job!(%{
        state: "scheduled",
        queue: "mailers",
        worker: "FreeObanUi.Workers.Scheduled",
        args: %{"to" => "a@example.com"},
        inserted_at: now,
        scheduled_at: DateTime.add(now, 3600, :second)
      })

    %{completed: completed, scheduled: scheduled}
  end

  test "lists jobs and filters by state and queue", %{conn: conn, completed: completed} do
    {:ok, view, html} = live(conn, ~p"/oban")

    assert html =~ "Oban Jobs"
    assert html =~ "FreeObanUi.Workers.Completed"
    assert html =~ "FreeObanUi.Workers.Scheduled"
    assert html =~ "completed"
    assert html =~ "mailers"

    html = view |> element("a", "completed") |> render_click()
    assert html =~ "FreeObanUi.Workers.Completed"
    refute html =~ "FreeObanUi.Workers.Scheduled"

    {:ok, view, _html} = live(conn, ~p"/oban?queue=mailers")
    html = render(view)
    assert html =~ "FreeObanUi.Workers.Scheduled"
    refute html =~ "FreeObanUi.Workers.Completed"

    {:ok, _view, html} = live(conn, ~p"/oban/#{completed.id}")
    assert html =~ "Job ##{completed.id}"
    assert html =~ "FreeObanUi.Workers.Completed"
    assert html =~ "Args"
    assert html =~ "id"
  end

  test "deletes a job from the detail page", %{conn: conn, completed: completed} do
    {:ok, view, _html} = live(conn, ~p"/oban/#{completed.id}")

    view
    |> element("button", "Delete")
    |> render_click()

    refute Repo.get(Oban.Job, completed.id)
  end

  test "retries a discarded job", %{conn: conn} do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    job =
      insert_job!(%{
        state: "discarded",
        queue: "default",
        worker: "FreeObanUi.Workers.Discarded",
        args: %{id: 9},
        attempt: 5,
        max_attempts: 5,
        discarded_at: now,
        inserted_at: now,
        scheduled_at: now,
        errors: [%{"attempt" => 5, "at" => "2024-01-01T00:00:00Z", "error" => "** (RuntimeError) boom"}]
      })

    {:ok, view, html} = live(conn, ~p"/oban/#{job.id}")
    assert html =~ "boom"

    view |> element("button", "Retry") |> render_click()

    retried = Repo.get!(Oban.Job, job.id)
    assert retried.state == "available"
  end

  defp insert_job!(attrs) do
    defaults = %{
      worker: "FreeObanUi.Workers.Example",
      args: %{},
      queue: "default",
      state: "available",
      meta: %{},
      tags: [],
      errors: [],
      attempt: 0,
      max_attempts: 20,
      priority: 0,
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
      scheduled_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
    }

    %Oban.Job{}
    |> Ecto.Changeset.cast(Map.merge(defaults, attrs), Map.keys(defaults))
    |> Repo.insert!()
  end
end
