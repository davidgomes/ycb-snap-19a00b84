defmodule FreeObanUiWeb.ObanLiveTest do
  use FreeObanUiWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias FreeObanUi.Repo

  test "lists jobs, filters by state, and opens a job", %{conn: conn} do
    available = insert_job("default", "available")
    retryable = insert_job("mailers", "retryable")

    {:ok, view, html} = live(conn, ~p"/oban")

    assert html =~ "Oban Jobs"
    assert html =~ "FreeObanUi.Workers.Noop"
    assert html =~ to_string(available.id)
    assert html =~ to_string(retryable.id)
    assert has_element?(view, "a", "available")
    assert has_element?(view, "a", "retryable")

    {:ok, _view, html} = live(conn, ~p"/oban?state=retryable")

    assert html =~ to_string(retryable.id)
    refute html =~ ">#{available.id}<"

    {:ok, _view, html} = live(conn, ~p"/oban/#{retryable.id}")

    assert html =~ "Job ##{retryable.id}"
    assert html =~ "mailers"
    assert html =~ "retryable"
  end

  test "retries, cancels, and deletes a job from the detail page", %{conn: conn} do
    job = insert_job("default", "retryable")

    {:ok, view, _html} = live(conn, ~p"/oban/#{job.id}")

    view |> element("button", "Retry") |> render_click()
    assert Repo.get!(Oban.Job, job.id).state == "available"

    scheduled = insert_job("default", "scheduled")
    {:ok, view, _html} = live(conn, ~p"/oban/#{scheduled.id}")
    view |> element("button", "Cancel") |> render_click()
    assert Repo.get!(Oban.Job, scheduled.id).state == "cancelled"

    {:ok, view, _html} = live(conn, ~p"/oban/#{job.id}")
    view |> element("button", "Delete") |> render_click()
    refute Repo.get(Oban.Job, job.id)
    assert_patch(view, ~p"/oban?#{[queue: nil, state: nil, page: "0"]}")
  end

  test "runs bulk delete on selected jobs", %{conn: conn} do
    first = insert_job("default", "completed")
    second = insert_job("default", "completed")

    {:ok, view, _html} = live(conn, ~p"/oban?state=completed")

    view |> element("input[phx-value-id='#{first.id}']") |> render_click()
    view |> element("button", "Delete") |> render_click()

    refute Repo.get(Oban.Job, first.id)
    assert Repo.get(Oban.Job, second.id)
  end

  defp insert_job(queue, state) do
    %{}
    |> Oban.Job.new(worker: "FreeObanUi.Workers.Noop", queue: queue)
    |> Repo.insert!()
    |> Ecto.Changeset.change(%{state: state})
    |> Repo.update!()
  end
end
