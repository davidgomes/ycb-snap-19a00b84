defmodule ObanChoreWeb.JobComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias ObanChoreWeb.JobComponent
  alias Phoenix.LiveView.Socket

  defp job(attrs \\ []) do
    struct!(%Oban.Job{id: 42, args: %{"reason" => "cleanup"}, state: :available}, attrs)
  end

  defp mount_job(job) do
    {:ok, socket} = JobComponent.update(%{id: job.id, job: job, selected: true}, %Socket{})
    socket
  end

  defp render_socket(socket) do
    socket.assigns |> JobComponent.render() |> rendered_to_string()
  end

  describe "render" do
    test "shows the job id, state and arguments" do
      html = render_component(JobComponent, id: 42, job: job(), selected: true)

      assert html =~ "oc-block"
      assert html =~ "ID: 42"
      assert html =~ "Available"
      assert html =~ "reason"
      assert html =~ "&quot;cleanup&quot;"
    end

    test "is hidden when not selected" do
      html = render_component(JobComponent, id: 42, job: job(), selected: false)

      assert html =~ "oc-hidden"
      refute html =~ "oc-block"
    end

    test "indicates when the job has no arguments" do
      html = render_component(JobComponent, id: 42, job: job(args: %{}), selected: true)

      assert html =~ "No arguments provided."
    end

    test "shows a waiting message while the job executes without logs" do
      assert render_component(JobComponent, id: 42, job: job(state: :executing), selected: true) =~
               "Waiting for logs..."

      assert render_component(JobComponent, id: 42, job: job(state: :available), selected: true) =~
               "No logs yet."
    end
  end

  describe "update/2" do
    test "starts without logs" do
      assert mount_job(job()).assigns.logs == []
    end

    test "prepends streamed log lines and renders them" do
      socket = mount_job(job(state: :executing))

      {:ok, socket} = JobComponent.update(%{new_log: "Starting backfill..."}, socket)
      {:ok, socket} = JobComponent.update(%{new_log: "Done!"}, socket)

      assert socket.assigns.logs == ["Done!", "Starting backfill..."]

      html = render_socket(socket)
      assert html =~ "Starting backfill..."
      assert html =~ "Done!"
      refute html =~ "Waiting for logs..."
    end

    test "updates the job state" do
      socket = mount_job(job(state: :executing))

      {:ok, socket} = JobComponent.update(%{new_state: :completed}, socket)

      assert socket.assigns.job.state == :completed
      assert render_socket(socket) =~ "Completed"
    end

    test "keeps the collected logs when the parent re-renders" do
      socket = mount_job(job())
      {:ok, socket} = JobComponent.update(%{new_log: "Working..."}, socket)

      {:ok, socket} = JobComponent.update(%{id: 42, job: job(), selected: false}, socket)

      assert socket.assigns.logs == ["Working..."]
      assert socket.assigns.selected == false
    end
  end
end
