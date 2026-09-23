defmodule Oban.Web.Pages.Jobs.DetailTest do
  use Oban.Web.Case

  import Phoenix.LiveViewTest

  setup do
    start_supervised_oban!()

    {:ok, live, _html} = live(build_conn(), "/oban")

    {:ok, live: live}
  end

  test "viewing job details", %{live: live} do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA)

    open_state(live, "available")
    open_details(live, job)

    assert page_title(live) =~ "WorkerA (#{job.id})"
  end

  test "viewing details for a job that was deleted falls back", %{live: live} do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA)

    open_state(live, "available")

    Repo.delete!(job)

    open_details(live, job)

    refute has_element?(live, "#job-details")
  end

  test "cancelling a job from the detail view", %{live: live} do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA)

    open_state(live, "available")
    open_details(live, job)

    assert has_element?(live, "#job-details")

    click_cancel(live)

    with_backoff(fn ->
      assert %{state: "cancelled"} = Repo.reload!(job)
    end)
  end

  test "immediately running a job from the detail view", %{live: live} do
    job = insert_job!([ref: 1], state: "scheduled", worker: WorkerA)

    open_state(live, "scheduled")
    open_details(live, job)

    assert has_element?(live, "#job-details")

    click_run_now(live)

    with_backoff(fn ->
      assert %{state: "available"} = Repo.reload!(job)
    end)
  end

  describe "awaitable signals" do
    test "omitting the signal section for jobs without signals", %{live: live} do
      job = insert_job!([ref: 1], state: "available", worker: WorkerA)

      open_state(live, "available")
      open_details(live, job)

      refute has_element?(live, "#job-signal")
    end

    test "displaying the deadline for jobs awaiting a signal", %{live: live} do
      wait_until = System.system_time(:millisecond) + :timer.hours(1)

      job =
        insert_job!([ref: 1],
          state: "scheduled",
          worker: WorkerA,
          meta: %{wait_until: wait_until}
        )

      open_state(live, "scheduled")
      open_details(live, job)

      assert has_element?(live, "#job-signal", "Awaiting Signal")
      assert has_element?(live, "#job-signal", "Deadline")
      refute has_element?(live, "#copy-signal")
    end

    test "displaying jobs awaiting a signal without a deadline", %{live: live} do
      job =
        insert_job!([ref: 1],
          state: "scheduled",
          worker: WorkerA,
          meta: %{wait_until: "infinity"}
        )

      open_state(live, "scheduled")
      open_details(live, job)

      assert has_element?(live, "#job-signal", "No deadline")
    end

    test "displaying the decoded payload for received signals", %{live: live} do
      signal =
        %{decision: "approved"}
        |> :erlang.term_to_binary()
        |> Base.encode64(padding: false)

      job =
        insert_job!([ref: 1],
          state: "available",
          worker: WorkerA,
          meta: %{signal: signal}
        )

      open_state(live, "available")
      open_details(live, job)

      assert has_element?(live, "#job-signal", "Received Signal")
      assert has_element?(live, "#job-signal", ~s(decision: "approved"))
      assert has_element?(live, "#copy-signal")
    end
  end

  describe "editing jobs" do
    test "edit form is visible for editable jobs", %{live: live} do
      job = insert_job!([ref: 1], state: "available", worker: WorkerA)

      open_state(live, "available")
      open_details(live, job)

      assert has_element?(live, "#edit-toggle")
      assert has_element?(live, "#job-edit-form")
      refute has_element?(live, "#edit-hint")
    end

    test "edit form is available for all editable states", %{live: live} do
      job = insert_job!([ref: 1], state: "retryable", worker: WorkerA)

      open_state(live, "retryable")
      open_details(live, job)

      refute has_element?(live, "#edit-hint")
      assert has_element?(live, "#job-edit-form")
    end

    test "updating job fields successfully", %{live: live} do
      job =
        insert_job!([ref: 1],
          state: "available",
          worker: WorkerA,
          priority: 0,
          max_attempts: 20,
          tags: []
        )

      open_state(live, "available")
      open_details(live, job)

      live
      |> form("#job-edit-form", %{
        "priority" => "5",
        "max_attempts" => "10",
        "tags" => "alpha, beta"
      })
      |> render_submit()

      with_backoff(fn ->
        updated = Repo.reload!(job)
        assert updated.priority == 5
        assert updated.max_attempts == 10
        assert updated.tags == ["alpha", "beta"]
      end)

      assert render(live) =~ "Job updated successfully"
    end

    test "updating unrelated fields does not change scheduled_at", %{live: live} do
      scheduled_at = DateTime.utc_now() |> DateTime.add(3600) |> DateTime.truncate(:second)

      job =
        insert_job!([ref: 1],
          state: "scheduled",
          worker: WorkerA,
          priority: 0,
          scheduled_at: scheduled_at
        )

      open_state(live, "scheduled")
      open_details(live, job)

      live
      |> form("#job-edit-form", %{"priority" => "3"})
      |> render_submit()

      with_backoff(fn ->
        updated = Repo.reload!(job)
        assert updated.priority == 3
        assert DateTime.compare(updated.scheduled_at, scheduled_at) == :eq
      end)
    end
  end

  defp open_state(live, state) do
    live
    |> element("#sidebar #states #filter-#{state}")
    |> render_click()
  end

  defp open_details(live, %{id: id}) do
    live
    |> element("#jobs-table #job-#{id} a")
    |> render_click()
  end

  defp click_cancel(live) do
    live
    |> element("#detail-cancel")
    |> render_click()
  end

  defp click_run_now(live) do
    live
    |> element("#detail-retry")
    |> render_click()
  end
end
