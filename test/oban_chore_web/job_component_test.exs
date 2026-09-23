defmodule ObanChoreWeb.JobComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias ObanChoreWeb.JobComponent
  alias Phoenix.LiveView.Socket

  defp job(attrs \\ []) do
    struct!(
      %Oban.Job{id: 42, args: %{"user_id" => 7, "reason" => "backfill"}, state: :executing},
      attrs
    )
  end

  defp mount_component(job, selected \\ true) do
    {:ok, socket} = JobComponent.update(%{id: job.id, job: job, selected: selected}, %Socket{})
    socket
  end

  defp render_socket(socket) do
    socket.assigns |> JobComponent.render() |> rendered_to_string()
  end

  describe "rendering" do
    test "shows the job's id, state and arguments" do
      html = render_component(JobComponent, id: 42, job: job(), selected: true)

      assert html =~ ~s(class="oc-block")
      assert html =~ "ID: 42"
      assert html =~ "Executing"
      assert html =~ ~s(<dt class="oc-job-arg-title">user_id</dt>)
      assert html =~ ~s(<dt class="oc-job-arg-title">reason</dt>)
      assert html =~ "&quot;backfill&quot;"
    end

    test "is hidden when it isn't the selected tab" do
      html = render_component(JobComponent, id: 42, job: job(), selected: false)

      assert html =~ ~s(class="oc-hidden")
    end

    test "says when the job has no arguments" do
      html = render_component(JobComponent, id: 42, job: job(args: %{}), selected: true)

      assert html =~ "No arguments provided."
    end

    test "waits for logs while the job is executing" do
      html = render_component(JobComponent, id: 42, job: job(), selected: true)

      assert html =~ "Waiting for logs..."
    end

    test "says there are no logs for jobs that aren't executing" do
      html = render_component(JobComponent, id: 42, job: job(state: :available), selected: true)

      assert html =~ "No logs yet."
      refute html =~ "Waiting for logs..."
    end
  end

  describe "update/2" do
    test "starts without logs" do
      socket = mount_component(job())

      assert socket.assigns.logs == []
      assert socket.assigns.job == job()
      assert socket.assigns.selected
    end

    test "collects streamed log lines, newest first" do
      socket = mount_component(job())

      {:ok, socket} = JobComponent.update(%{id: 42, new_log: "Starting backfill..."}, socket)
      {:ok, socket} = JobComponent.update(%{id: 42, new_log: "Done!"}, socket)

      assert socket.assigns.logs == ["Done!", "Starting backfill..."]

      html = render_socket(socket)
      assert html =~ ~s(<span class="oc-log-content">Starting backfill...</span>)
      assert html =~ ~s(<span class="oc-log-content">Done!</span>)
      refute html =~ "Waiting for logs..."
    end

    test "updates the job state" do
      socket = mount_component(job())

      {:ok, socket} = JobComponent.update(%{id: 42, new_state: :completed}, socket)

      assert socket.assigns.job.state == :completed
      assert render_socket(socket) =~ "Completed"
    end

    test "keeps collected logs when the parent re-renders it" do
      socket = mount_component(job())
      {:ok, socket} = JobComponent.update(%{id: 42, new_log: "Working..."}, socket)

      {:ok, socket} = JobComponent.update(%{id: 42, job: job(), selected: false}, socket)

      assert socket.assigns.logs == ["Working..."]
      refute socket.assigns.selected
    end
  end
end
