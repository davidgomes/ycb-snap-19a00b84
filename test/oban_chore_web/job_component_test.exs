defmodule ObanChoreWeb.JobComponentTest do
  use ExUnit.Case, async: true

  alias ObanChoreWeb.JobComponent

  defp mount_component(assigns) do
    {:ok, socket} = JobComponent.update(assigns, %Phoenix.LiveView.Socket{})
    socket
  end

  defp render_html(socket) do
    socket.assigns
    |> JobComponent.render()
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp job(attrs \\ []) do
    struct!(%Oban.Job{id: 7, state: :available, args: %{}}, attrs)
  end

  test "initial update assigns the job and empty logs" do
    socket = mount_component(%{id: 7, job: job(), selected: true})

    assert socket.assigns.job.id == 7
    assert socket.assigns.logs == []
  end

  test "subsequent updates keep existing logs" do
    socket = mount_component(%{id: 7, job: job(), selected: true})
    {:ok, socket} = JobComponent.update(%{new_log: "hello"}, socket)
    {:ok, socket} = JobComponent.update(%{id: 7, job: job(), selected: false}, socket)

    assert socket.assigns.logs == ["hello"]
    refute socket.assigns.selected
  end

  test "new_log prepends messages" do
    socket = mount_component(%{id: 7, job: job(), selected: true})
    {:ok, socket} = JobComponent.update(%{new_log: "first"}, socket)
    {:ok, socket} = JobComponent.update(%{new_log: "second"}, socket)

    assert socket.assigns.logs == ["second", "first"]
  end

  test "new_state updates the job state" do
    socket = mount_component(%{id: 7, job: job(), selected: true})
    {:ok, socket} = JobComponent.update(%{new_state: :completed}, socket)

    assert socket.assigns.job.state == :completed
  end

  test "renders job arguments, id and state" do
    html =
      %{id: 7, job: job(args: %{"user_id" => 42}), selected: true}
      |> mount_component()
      |> render_html()

    assert html =~ "oc-block"
    assert html =~ "ID: 7"
    assert html =~ "Available"
    assert html =~ "user_id"
    assert html =~ "42"
  end

  test "renders placeholders when there are no args or logs" do
    html =
      %{id: 7, job: job(), selected: false}
      |> mount_component()
      |> render_html()

    assert html =~ "oc-hidden"
    assert html =~ "No arguments provided."
    assert html =~ "No logs yet."
  end

  test "renders a waiting message while executing without logs" do
    html =
      %{id: 7, job: job(state: :executing), selected: true}
      |> mount_component()
      |> render_html()

    assert html =~ "Waiting for logs..."
  end

  test "renders received logs" do
    socket = mount_component(%{id: 7, job: job(state: :executing), selected: true})
    {:ok, socket} = JobComponent.update(%{new_log: "Processing users"}, socket)

    html = render_html(socket)

    assert html =~ "Processing users"
    refute html =~ "Waiting for logs..."
  end
end
