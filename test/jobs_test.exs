defmodule Oban.Console.JobsTest do
  use ExUnit.Case

  alias Oban.Console.Jobs
  alias Oban.Console.Repo
  alias Oban.Console.Storage

  import ExUnit.CaptureIO
  import Factory

  setup do
    System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", "")
    System.put_env("OBAN_CONSOLE_JOBS_LAST_IDS", "")

    Storage.delete_profile_file()

    :ok
  end

  describe "list/0" do
    test "return jobs" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert ObanMock.jobs() == Jobs.list()
    end

    test "limits the results by default" do
      stub_repo_all_capturing_query()

      Jobs.list()

      assert_received {:query, query}
      assert %{expr: 20} = query.limit
      assert [] == query.wheres
    end
  end

  describe "list/1" do
    test "filters by ids, states, queues and workers" do
      stub_repo_all_capturing_query()

      Jobs.list(
        ids: [1, 2],
        states: ["available"],
        queues: ["default"],
        workers: ["ProcessOrder"],
        limit: 5
      )

      assert_received {:query, query}
      assert 4 == length(query.wheres)
      assert [5] == Enum.map(query.limit.params, fn {value, _type} -> value end)
    end

    test "splits the workers between included and excluded patterns" do
      stub_repo_all_capturing_query()

      Jobs.list(workers: ["ProcessOrder", "-SendEmail"])

      assert_received {:query, query}
      assert 2 == length(query.wheres)

      params = Enum.flat_map(query.wheres, fn where -> Enum.map(where.params, &elem(&1, 0)) end)

      assert "%ProcessOrder%" in params
      assert "%SendEmail%" in params
    end

    test "ignores empty filters" do
      stub_repo_all_capturing_query()

      Jobs.list(ids: [], states: nil, queues: [], workers: nil)

      assert_received {:query, query}
      assert [] == query.wheres
    end
  end

  describe "show_list/0" do
    test "shows the list" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list()
    end

    test "stores the listed ids and the used opts" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      capture_io(fn -> assert :ok = Jobs.show_list() end)

      assert [1, 2, 3, 4, 5, 6, 7] == Storage.get_last_jobs_ids()
      assert 20 == Keyword.get(Storage.get_last_jobs_opts(), :limit)
    end

    test "reuses the last used opts" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      Storage.set_last_jobs_opts(limit: 5, states: ["completed"])

      capture_io(fn -> assert :ok = Jobs.show_list() end)

      opts = Storage.get_last_jobs_opts()

      assert 5 == Keyword.get(opts, :limit)
      assert ["completed"] == Keyword.get(opts, :states)
    end

    test "shows an empty list when there aren't jobs" do
      Mimic.stub(Repo, :all, fn _ -> [] end)

      output = capture_io(fn -> assert :ok = Jobs.show_list() end)

      assert output =~ "No records found"
    end

    test "cleans the stored opts and retries when listing fails" do
      Mimic.stub(Repo, :all, fn _ ->
        case Process.put(:listed, true) do
          nil -> raise ArgumentError, "invalid limit"
          true -> ObanMock.jobs()
        end
      end)

      output = capture_io(fn -> assert :ok = Jobs.show_list(limit: "invalid") end)

      assert output =~ "invalid limit"
      assert 20 == Keyword.get(Storage.get_last_jobs_opts(), :limit)
    end

    test "with a profile shows list adding the opts to the profile" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      Storage.find_or_create_profile("API", [])

      assert :ok = Jobs.show_list()

      assert {"API", %{"filters" => [%{"ids" => [], "limit" => 20, "states" => []}]}} =
               Storage.get_profile()

      assert :ok = Jobs.show_list(limit: 50, states: ["scheduled"])

      assert {"API",
              %{
                "filters" => [
                  %{
                    "ids" => [],
                    "limit" => 50,
                    "states" => ["scheduled"]
                  },
                  %{"ids" => [], "limit" => 20, "states" => []}
                ]
              }} = Storage.get_profile()
    end
  end

  describe "show_list/1" do
    test "converts the states shortcuts" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      capture_io(fn -> assert :ok = Jobs.show_list(states: ["1", "5", "cancelled"]) end)

      assert ["available", "completed", "cancelled"] ==
               Keyword.get(Storage.get_last_jobs_opts(), :states)
    end

    test "expands the in_progress and failed states" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      capture_io(fn -> assert :ok = Jobs.show_list(states: ["in_progress", "failed"]) end)

      assert ~w[available scheduled retryable executing cancelled discarded] ==
               Keyword.get(Storage.get_last_jobs_opts(), :states)
    end

    test "uses the last listed ids when the id 0 is given" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      Storage.set_last_jobs_ids([10, 11])

      capture_io(fn -> assert :ok = Jobs.show_list(ids: [0]) end)

      assert [10, 11] == Keyword.get(Storage.get_last_jobs_opts(), :ids)
    end

    test "uses the default limit when it is nil" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      capture_io(fn -> assert :ok = Jobs.show_list(limit: nil) end)

      assert 20 == Keyword.get(Storage.get_last_jobs_opts(), :limit)
    end
  end

  describe "clean_storage/0" do
    test "cleans the last used opts" do
      Storage.set_last_jobs_opts(limit: 5)

      Jobs.clean_storage()

      assert [] == Storage.get_last_jobs_opts()
    end
  end

  describe "debug_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.debug_jobs([])
    end

    test "with a list of ids" do
      stub_oban_get_job(fn id -> build(:job, id: id) end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs([1, 2]) end)

      assert_received {:got_job, 1}
      assert_received {:got_job, 2}
      assert output =~ "| 1"
      assert output =~ "| 2"
    end

    test "with a single id" do
      stub_oban_get_job(fn id -> build(:job, id: id, worker: "ProcessOrder") end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs(1) end)

      assert output =~ "| 1"
      assert output =~ "ProcessOrder"
    end

    test "with an unknown id" do
      stub_oban_get_job(fn _id -> nil end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs(1) end)

      assert output =~ "Job not found"
    end

    test "with an invalid id" do
      output = capture_io(fn -> assert :ok = Jobs.debug_jobs("one") end)

      assert output =~ "Job ID is not valid"
    end
  end

  describe "retry_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.retry_jobs([])
    end

    test "with a list of ids" do
      Mimic.stub(Oban, :retry_job, fn id -> send(self(), {:retried, id}) && :ok end)

      output = capture_io(fn -> assert :ok = Jobs.retry_jobs([1, 2]) end)

      assert_received {:retried, 1}
      assert_received {:retried, 2}
      assert output =~ "Retried"
    end

    test "with a single id" do
      Mimic.stub(Oban, :retry_job, fn id -> send(self(), {:retried, id}) && :ok end)

      output = capture_io(fn -> assert :ok = Jobs.retry_jobs(1) end)

      assert_received {:retried, 1}
      assert output =~ "Retried"
      assert output =~ "| 1"
    end

    test "with an invalid id" do
      Mimic.stub(Oban, :retry_job, fn id -> send(self(), {:retried, id}) && :ok end)

      output = capture_io(fn -> assert :ok = Jobs.retry_jobs("one") end)

      refute_received {:retried, _}
      assert output =~ "Job ID is not valid"
    end
  end

  describe "cancel_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.cancel_jobs([])
    end

    test "with a list of ids" do
      Mimic.stub(Oban, :cancel_job, fn id -> send(self(), {:cancelled, id}) && :ok end)

      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs([1, 2]) end)

      assert_received {:cancelled, 1}
      assert_received {:cancelled, 2}
      assert output =~ "Cancelled"
    end

    test "with a single id" do
      Mimic.stub(Oban, :cancel_job, fn id -> send(self(), {:cancelled, id}) && :ok end)

      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs(1) end)

      assert_received {:cancelled, 1}
      assert output =~ "Cancelled"
      assert output =~ "| 1"
    end

    test "with an invalid id" do
      Mimic.stub(Oban, :cancel_job, fn id -> send(self(), {:cancelled, id}) && :ok end)

      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs("one") end)

      refute_received {:cancelled, _}
      assert output =~ "Job ID is not valid"
    end
  end

  defp stub_repo_all_capturing_query do
    parent = self()

    Mimic.stub(Repo, :all, fn query ->
      send(parent, {:query, query})

      []
    end)
  end

  defp stub_oban_get_job(fun) do
    Mimic.stub(Oban, :config, fn _name -> :config end)

    Mimic.stub(Oban.Repo, :get, fn :config, Oban.Job, id ->
      send(self(), {:got_job, id})

      fun.(id)
    end)
  end
end
