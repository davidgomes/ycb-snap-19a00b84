defmodule ObanChore.QueriesTest do
  use ExUnit.Case, async: false

  alias ObanChore.Test.MockRepo

  setup do
    # Start a minimal Oban instance using our MockRepo
    # We use a unique name to avoid conflicts with other tests
    oban_name = ObanChore.TestOban

    start_supervised!(
      {Oban,
       name: oban_name,
       repo: MockRepo,
       queues: [],
       notifier: Oban.Notifiers.Isolated,
       peer: Oban.Peers.Isolated}
    )

    {:ok, oban_name: oban_name}
  end

  test "count_running/2 generates the correct Ecto query", %{oban_name: oban_name} do
    ObanChore.count_running(SomeWorker, oban_name)

    assert_receive {:repo_aggregate, query}
    assert query.from.source == {"oban_jobs", Oban.Job}

    query_str = inspect(query)
    assert query_str =~ "j0.state in [\"available\", \"scheduled\", \"executing\"]"
    assert query_str =~ "j0.worker == ^\"SomeWorker\""
  end

  test "count_running/2 returns the count from the repo", %{oban_name: oban_name} do
    MockRepo.stub(:aggregate, 3)

    assert ObanChore.count_running(SomeWorker, oban_name) == 3
  end

  test "running_with_args?/3 generates the correct Ecto query", %{oban_name: oban_name} do
    ObanChore.running_with_args?(SomeWorker, %{user_id: 123}, oban_name)

    assert_receive {:repo_exists, query}
    assert query.from.source == {"oban_jobs", Oban.Job}

    query_str = inspect(query)
    assert query_str =~ "j0.state in [\"available\", \"scheduled\", \"executing\"]"
    assert query_str =~ "j0.worker == ^\"SomeWorker\""
    assert query_str =~ "fragment(\"? @> ?\", j0.args, ^"
  end

  test "running_with_args?/3 matches args with string keys", %{oban_name: oban_name} do
    ObanChore.running_with_args?(SomeWorker, %{user_id: 123, reason: "backfill"}, oban_name)

    assert_receive {:repo_exists, query}
    assert [_state, _worker, %{params: [{contained, _type}]}] = query.wheres
    assert contained == %{"user_id" => 123, "reason" => "backfill"}
  end

  test "running_with_args?/3 returns whether a matching job exists", %{oban_name: oban_name} do
    refute ObanChore.running_with_args?(SomeWorker, %{}, oban_name)

    MockRepo.stub(:exists?, true)

    assert ObanChore.running_with_args?(SomeWorker, %{}, oban_name)
  end

  test "list_active_jobs/2 generates the correct Ecto query", %{oban_name: oban_name} do
    ObanChore.list_active_jobs(SomeWorker, oban_name)

    assert_receive {:repo_all, query}
    assert query.from.source == {"oban_jobs", Oban.Job}

    query_str = inspect(query)
    assert query_str =~ "j0.state in [\"available\", \"scheduled\", \"executing\"]"
    assert query_str =~ "j0.worker == ^\"SomeWorker\""
  end

  test "list_active_jobs/2 converts job states to atoms", %{oban_name: oban_name} do
    MockRepo.stub(:all, [
      %Oban.Job{id: 1, worker: "SomeWorker", state: "available"},
      %Oban.Job{id: 2, worker: "SomeWorker", state: "executing"}
    ])

    assert [%Oban.Job{id: 1, state: :available}, %Oban.Job{id: 2, state: :executing}] =
             ObanChore.list_active_jobs(SomeWorker, oban_name)
  end

  test "worker names are matched without the Elixir prefix", %{oban_name: oban_name} do
    ObanChore.count_running(MyApp.Chores.Backfill, oban_name)
    assert_receive {:repo_aggregate, module_query}

    ObanChore.count_running("MyApp.Chores.Backfill", oban_name)
    assert_receive {:repo_aggregate, string_query}

    assert inspect(module_query) =~ "j0.worker == ^\"MyApp.Chores.Backfill\""
    assert inspect(string_query) =~ "j0.worker == ^\"MyApp.Chores.Backfill\""
  end
end
