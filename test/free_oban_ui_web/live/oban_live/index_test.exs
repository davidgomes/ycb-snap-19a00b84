defmodule FreeObanUiWeb.ObanLive.IndexTest do
  use FreeObanUiWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias FreeObanUi.Repo
  alias FreeObanUiWeb.ObanLive.Index

  test "lists jobs, filters them, and opens a job", %{conn: conn} do
    scheduled = insert_job(%{state: "scheduled", queue: "default", worker: "Work.Scheduled"})
    insert_job(%{state: "retryable", queue: "mailers", worker: "Work.Mailer"})

    {:ok, view, html} = live(conn, ~p"/oban")

    assert html =~ "Oban Jobs"
    assert html =~ "Work.Scheduled"
    assert html =~ "Work.Mailer"
    assert html =~ "scheduled (1)"
    assert html =~ "retryable (1)"
    assert html =~ "default (1)"
    assert html =~ "mailers (1)"

    html = view |> element("a", "scheduled") |> render_click()
    assert html =~ "Work.Scheduled"
    refute html =~ "Work.Mailer"
    assert html =~ "Clear"

    html = view |> element("a", "Clear") |> render_click()
    assert html =~ "Work.Scheduled"
    assert html =~ "Work.Mailer"

    html = view |> element("a", "mailers") |> render_click()
    assert html =~ "Work.Mailer"
    refute html =~ "Work.Scheduled"

    {:ok, _view, html} = live(conn, ~p"/oban/#{scheduled.id}")

    assert html =~ "Job ##{scheduled.id}"
    assert html =~ "Work.Scheduled"
    assert html =~ "Args"
    assert html =~ "Meta"
    assert html =~ "Run"
    assert html =~ "Cancel"
  end

  test "runs, retries, cancels, and deletes a job", %{conn: conn} do
    scheduled = insert_job(%{state: "scheduled", worker: "Work.Run"})
    completed = insert_job(%{state: "completed", worker: "Work.Retry"})
    executing = insert_job(%{state: "executing", worker: "Work.Cancel"})
    cancelled = insert_job(%{state: "cancelled", worker: "Work.Gone"})
    doomed = insert_job(%{state: "discarded", worker: "Work.Delete"})

    {:ok, view, _html} = live(conn, ~p"/oban/#{scheduled.id}")
    view |> element("button", "Run") |> render_click()
    assert Repo.reload!(scheduled).state == "available"

    {:ok, view, _html} = live(conn, ~p"/oban/#{completed.id}")
    view |> element("button", "Retry") |> render_click()
    assert Repo.reload!(completed).state == "available"

    {:ok, view, _html} = live(conn, ~p"/oban/#{executing.id}")
    view |> element("button", "Cancel") |> render_click()
    assert Repo.reload!(executing).state == "cancelled"

    {:ok, view, _html} = live(conn, ~p"/oban/#{cancelled.id}")
    view |> element("button", "Delete") |> render_click()
    assert Repo.get(Oban.Job, cancelled.id) == nil

    {:ok, view, _html} = live(conn, ~p"/oban/#{doomed.id}")
    html = view |> element("button", "Delete") |> render_click()
    assert html =~ "Job ##{doomed.id} deleted"
    assert html =~ "Oban Jobs"
    refute Repo.get(Oban.Job, doomed.id)
  end

  test "paginates 25 jobs per page", %{conn: conn} do
    now = DateTime.utc_now()

    for n <- 1..26 do
      insert_job(%{
        worker: "Worker#{String.pad_leading(Integer.to_string(n), 2, "0")}",
        inserted_at: DateTime.add(now, -n, :second)
      })
    end

    {:ok, view, html} = live(conn, ~p"/oban")

    assert html =~ "Worker01"
    refute html =~ "Worker26"

    html = view |> element("button", "Next") |> render_click()
    assert html =~ "Worker26"
    refute html =~ "Worker01"
  end

  test "toggles auto-refresh", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/oban")
    assert html =~ "Disable Auto-refresh"

    html = view |> element("button", "Disable Auto-refresh") |> render_click()
    assert html =~ "Enable Auto-refresh"
  end

  test "available actions follow the job state" do
    assert Index.available_actions("available") == ~w(cancel delete)
    assert Index.available_actions("executing") == ~w(cancel)
    assert Index.available_actions("scheduled") == ~w(run cancel delete)
    assert Index.available_actions("retryable") == ~w(retry cancel delete)
    assert Index.available_actions("cancelled") == ~w(retry delete)
    assert Index.available_actions("discarded") == ~w(retry delete)
    assert Index.available_actions("completed") == ~w(retry delete)
    assert Index.available_actions("complete") == ~w(retry delete)
    assert Index.available_actions(nil) == ~w(delete)
  end

  test "from_now_short formats past and future timestamps" do
    now = ~U[2024-09-18 12:00:00Z]

    assert Index.from_now_short(now, DateTime.add(now, -10, :second)) == "10s ago"
    assert Index.from_now_short(now, DateTime.add(now, 90, :second)) == "in 1m"
    assert Index.from_now_short(now, now) == "now"
  end

  defp insert_job(attrs) do
    now = DateTime.utc_now()

    defaults = %{
      state: "available",
      queue: "default",
      worker: "FreeObanUi.ExampleWorker",
      args: %{"hello" => "world"},
      meta: %{"source" => "test"},
      tags: ["demo"],
      errors: [],
      attempt: 1,
      max_attempts: 20,
      priority: 0,
      scheduled_at: now,
      inserted_at: now
    }

    %Oban.Job{}
    |> Ecto.Changeset.cast(Map.merge(defaults, attrs), Map.keys(defaults))
    |> Repo.insert!()
  end
end
