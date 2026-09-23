defmodule ObanChoreWeb.ChoreComponentTest do
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias ObanChore.Test.MockRepo
  alias ObanChoreWeb.ChoreComponent
  alias Phoenix.LiveView.Socket

  defmodule BackfillChore do
    use ObanChore.Worker,
      name: "User Backfill",
      fields: [
        user_id: [type: :integer, required: true, label: "User ID"],
        reason: [type: :textarea, default: "Manual update"],
        role: [type: :select, options: [Admin: "admin", Viewer: "viewer"], prompt: "Pick a role"],
        notify: [type: :checkbox, label: "Notify user?"]
      ]

    @impl Oban.Worker
    def perform(%Oban.Job{args: args}) do
      send(self(), {:performed, args})
      :ok
    end
  end

  defmodule UniqueChore do
    use ObanChore.Worker,
      name: "Unique Chore",
      unique: [period: 60],
      fields: [user_id: [type: :integer]]

    @impl Oban.Worker
    def perform(_job), do: :ok
  end

  setup do
    start_supervised!(
      {Oban, name: Oban, repo: MockRepo, testing: :inline, notifier: Oban.Notifiers.Isolated}
    )

    :ok
  end

  defp mount_chore(module) do
    socket = %Socket{
      assigns: %{__changed__: %{}, flash: %{}, myself: %Phoenix.LiveComponent.CID{cid: 1}}
    }

    {:ok, socket} =
      ChoreComponent.update(
        %{id: module, chore: module.__chore_info__(), selected: true},
        socket
      )

    socket
  end

  defp render_socket(socket) do
    socket.assigns |> ChoreComponent.render() |> rendered_to_string()
  end

  defp render_chore(module, selected \\ true) do
    render_component(ChoreComponent,
      id: module,
      chore: module.__chore_info__(),
      selected: selected
    )
  end

  describe "render" do
    test "renders an input for every declared field" do
      html = render_chore(BackfillChore)

      assert html =~ "oc-block"
      assert html =~ ~s(name="args[user_id]")
      assert html =~ "User ID"
      assert html =~ ~s(<textarea id="args_reason" name="args[reason]")
      assert html =~ ~s(<select id="args_role" name="args[role]")
      assert html =~ ~s(<option value="">Pick a role</option>)
      assert html =~ ~s(<option value="admin">Admin</option>)
      assert html =~ ~s(type="checkbox" id="args_notify" name="args[notify]")
      assert html =~ "Notify user?"
      assert html =~ "Execute Chore"
    end

    test "prefills field defaults" do
      assert render_chore(BackfillChore) =~ "Manual update</textarea>"
    end

    test "is hidden when not selected" do
      html = render_chore(BackfillChore, false)

      assert html =~ "oc-hidden"
      refute html =~ "oc-block"
    end

    test "lets the user toggle uniqueness when the worker does not define it" do
      html = render_chore(BackfillChore)

      assert html =~ ~s(id="unique-Elixir.ObanChoreWeb.ChoreComponentTest.BackfillChore")
      refute html =~ "Uniqueness is enforced by the worker definition."
    end

    test "disables the uniqueness toggle when the worker defines unique options" do
      html = render_chore(UniqueChore)

      assert html =~ "disabled"
      assert html =~ "Uniqueness is enforced by the worker definition."
    end
  end

  describe "validate" do
    test "shows validation errors for invalid params" do
      socket = mount_chore(BackfillChore)

      {:noreply, socket} =
        ChoreComponent.handle_event("validate", %{"args" => %{"user_id" => ""}}, socket)

      assert socket.assigns.form.errors == [user_id: {"can't be blank", [validation: :required]}]
      assert render_socket(socket) =~ "can&#39;t be blank"
    end

    test "clears a pending duplicate warning" do
      socket = mount_chore(BackfillChore)
      socket = put_in(socket.assigns.duplicate_warning, %{"user_id" => "1"})

      {:noreply, socket} =
        ChoreComponent.handle_event("validate", %{"args" => %{"user_id" => "1"}}, socket)

      assert socket.assigns.duplicate_warning == nil
      assert socket.assigns.form.errors == []
    end
  end

  describe "execute" do
    test "enqueues the chore with the casted args and notifies the parent" do
      socket = mount_chore(BackfillChore)

      params = %{
        "user_id" => "7",
        "reason" => "Manual update",
        "role" => "admin",
        "notify" => "true"
      }

      {:noreply, socket} = ChoreComponent.handle_event("execute", %{"args" => params}, socket)

      assert_received {:performed,
                       %{
                         "user_id" => 7,
                         "reason" => "Manual update",
                         "role" => "admin",
                         "notify" => true
                       }}

      assert_received {:job_enqueued, %Oban.Job{} = job, BackfillChore}
      assert job.worker == "ObanChoreWeb.ChoreComponentTest.BackfillChore"
      assert socket.assigns.flash == %{"info" => "Successfully enqueued User Backfill"}
    end

    test "makes the job unique per args by default" do
      socket = mount_chore(BackfillChore)
      assert socket.assigns.unique_execution

      ChoreComponent.handle_event("execute", %{"args" => %{"user_id" => "7"}}, socket)

      assert_received {:job_enqueued, job, BackfillChore}
      assert job.unique.period == :infinity
      assert job.unique.states == [:available, :scheduled, :executing]
    end

    test "does not add uniqueness once the toggle is turned off" do
      socket = mount_chore(BackfillChore)

      {:noreply, socket} = ChoreComponent.handle_event("toggle_unique", %{}, socket)
      refute socket.assigns.unique_execution

      ChoreComponent.handle_event("execute", %{"args" => %{"user_id" => "7"}}, socket)

      assert_received {:job_enqueued, job, BackfillChore}
      assert job.unique == nil
    end

    test "keeps the worker's own unique options" do
      socket = mount_chore(UniqueChore)

      ChoreComponent.handle_event("execute", %{"args" => %{"user_id" => "7"}}, socket)

      assert_received {:job_enqueued, job, UniqueChore}
      assert job.unique.period == 60
    end

    test "does not enqueue invalid params and shows the errors" do
      socket = mount_chore(BackfillChore)

      {:noreply, socket} =
        ChoreComponent.handle_event("execute", %{"args" => %{"user_id" => "abc"}}, socket)

      refute_received {:job_enqueued, _job, _module}
      assert socket.assigns.form.source.action == :insert
      assert [user_id: {"is invalid", _}] = socket.assigns.form.errors
    end

    test "asks for confirmation when a job with the same args is already active" do
      MockRepo.stub(:exists?, true)
      socket = mount_chore(BackfillChore)
      params = %{"user_id" => "7"}

      {:noreply, socket} = ChoreComponent.handle_event("execute", %{"args" => params}, socket)

      refute_received {:job_enqueued, _job, _module}
      assert socket.assigns.duplicate_warning == params
      assert render_socket(socket) =~ "Duplicate Execution Warning"
    end
  end

  describe "duplicate confirmation" do
    setup do
      MockRepo.stub(:exists?, true)
      socket = mount_chore(BackfillChore)

      {:noreply, socket} =
        ChoreComponent.handle_event("execute", %{"args" => %{"user_id" => "7"}}, socket)

      %{socket: socket}
    end

    test "confirm_execute enqueues the job anyway", %{socket: socket} do
      {:noreply, socket} = ChoreComponent.handle_event("confirm_execute", %{}, socket)

      assert_received {:job_enqueued, job, BackfillChore}
      assert job.args == %{"user_id" => 7}
      assert socket.assigns.duplicate_warning == nil
      assert socket.assigns.flash == %{"info" => "Successfully enqueued User Backfill"}
    end

    test "cancel_execute dismisses the warning without enqueuing", %{socket: socket} do
      {:noreply, socket} = ChoreComponent.handle_event("cancel_execute", %{}, socket)

      refute_received {:job_enqueued, _job, _module}
      assert socket.assigns.duplicate_warning == nil
      refute render_socket(socket) =~ "Duplicate Execution Warning"
    end
  end
end
