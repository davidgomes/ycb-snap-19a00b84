defmodule ObanChoreWeb.ChoreComponentTest do
  use ExUnit.Case, async: false

  alias ObanChore.Test.MockRepo
  alias ObanChoreWeb.ChoreComponent
  alias Phoenix.LiveView.Socket

  defmodule BackfillChore do
    use ObanChore.Worker,
      name: "Backfill",
      fields: [
        user_id: [type: :integer, required: true],
        reason: [type: :string, default: "Manual"]
      ]

    @impl Oban.Worker
    def perform(%Oban.Job{args: args}) do
      send(self(), {:performed, args})
      :ok
    end
  end

  defmodule UniqueChore do
    use ObanChore.Worker,
      name: "Unique Backfill",
      unique: [period: 60],
      fields: [user_id: [type: :integer, required: true]]

    @impl Oban.Worker
    def perform(%Oban.Job{args: args}) do
      send(self(), {:performed, args})
      :ok
    end
  end

  setup do
    start_supervised!({Oban, repo: MockRepo, testing: :inline, notifier: Oban.Notifiers.Isolated})

    :ok
  end

  # update/2 builds its form from an Ecto changeset, which needs phoenix_ecto
  # (provided by the host app, not a dependency here), so the socket starts
  # from the assigns update/2 sets instead.
  defp socket(chore_module, assigns \\ []) do
    chore = chore_module.__chore_info__()

    %Socket{assigns: %{__changed__: %{}, flash: %{}}}
    |> Phoenix.Component.assign(
      id: chore.module,
      chore: chore,
      selected: true,
      duplicate_warning: nil,
      unique_execution: true
    )
    |> Phoenix.Component.assign(assigns)
  end

  test "toggle_unique flips unique execution" do
    {:noreply, socket} = ChoreComponent.handle_event("toggle_unique", %{}, socket(BackfillChore))
    refute socket.assigns.unique_execution

    {:noreply, socket} = ChoreComponent.handle_event("toggle_unique", %{}, socket)
    assert socket.assigns.unique_execution
  end

  describe "execute" do
    test "enqueues the chore with the casted arguments" do
      params = %{"user_id" => "7", "reason" => "Refund"}

      {:noreply, socket} =
        ChoreComponent.handle_event("execute", %{"args" => params}, socket(BackfillChore))

      assert_received {:performed, %{"user_id" => 7, "reason" => "Refund"}}
      assert_received {:job_enqueued, %Oban.Job{} = job, BackfillChore}
      assert job.worker == "ObanChoreWeb.ChoreComponentTest.BackfillChore"
      assert job.args == %{"user_id" => 7, "reason" => "Refund"}
      assert socket.assigns.flash == %{"info" => "Successfully enqueued Backfill"}
    end

    test "checks for a running job with the same casted arguments first" do
      params = %{"user_id" => "7", "reason" => "Refund"}

      ChoreComponent.handle_event("execute", %{"args" => params}, socket(BackfillChore))

      assert_received {:repo_exists, query}
      assert inspect(query) =~ ~s(j0.worker == ^"ObanChoreWeb.ChoreComponentTest.BackfillChore")
      assert [_state, _worker, %{params: [{contained, _type}]}] = query.wheres
      assert contained == %{"user_id" => 7, "reason" => "Refund"}
    end

    test "makes the job unique per arguments while unique execution is on" do
      ChoreComponent.handle_event(
        "execute",
        %{"args" => %{"user_id" => "7"}},
        socket(BackfillChore)
      )

      assert_received {:job_enqueued, job, BackfillChore}
      assert job.unique.period == :infinity
      assert Enum.sort(job.unique.states) == Enum.sort([:available, :scheduled, :executing])
    end

    test "doesn't make the job unique when unique execution is off" do
      socket = socket(BackfillChore, unique_execution: false)

      ChoreComponent.handle_event("execute", %{"args" => %{"user_id" => "7"}}, socket)

      assert_received {:job_enqueued, job, BackfillChore}
      assert job.unique == nil
    end

    test "keeps the worker's own unique options" do
      ChoreComponent.handle_event(
        "execute",
        %{"args" => %{"user_id" => "7"}},
        socket(UniqueChore)
      )

      assert_received {:job_enqueued, job, UniqueChore}
      assert job.unique.period == 60
    end

    test "asks for confirmation instead of enqueuing when a matching job is running" do
      MockRepo.stub(:exists?, true)
      params = %{"user_id" => "7"}

      {:noreply, socket} =
        ChoreComponent.handle_event("execute", %{"args" => params}, socket(BackfillChore))

      assert socket.assigns.duplicate_warning == params
      assert socket.assigns.flash == %{}
      refute_received {:performed, _}
      refute_received {:job_enqueued, _, _}
    end
  end

  test "confirm_execute enqueues the pending arguments and clears the warning" do
    socket = socket(BackfillChore, duplicate_warning: %{"user_id" => "7"})

    {:noreply, socket} = ChoreComponent.handle_event("confirm_execute", %{}, socket)

    assert_received {:performed, %{"user_id" => 7}}
    assert_received {:job_enqueued, %Oban.Job{args: %{"user_id" => 7}}, BackfillChore}
    assert socket.assigns.duplicate_warning == nil
    assert socket.assigns.flash == %{"info" => "Successfully enqueued Backfill"}
  end

  test "cancel_execute clears the warning without enqueuing" do
    socket = socket(BackfillChore, duplicate_warning: %{"user_id" => "7"})

    {:noreply, socket} = ChoreComponent.handle_event("cancel_execute", %{}, socket)

    assert socket.assigns.duplicate_warning == nil
    refute_received {:performed, _}
    refute_received {:job_enqueued, _, _}
  end
end
