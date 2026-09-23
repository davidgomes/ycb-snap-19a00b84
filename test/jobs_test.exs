defmodule Oban.Console.JobsTest do
  use ExUnit.Case

  import ExUnit.CaptureIO
  import Factory
  import Mimic

  alias Oban.Console.Jobs
  alias Oban.Console.Repo
  alias Oban.Console.Storage

  setup :verify_on_exit!

  describe "list/0" do
    test "return jobs" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert ObanMock.jobs() == Jobs.list()
    end

    test "limits to 20 jobs without filters" do
      Mimic.expect(Repo, :all, fn query ->
        assert [] = query.wheres
        assert %{expr: 20, params: []} = query.limit

        []
      end)

      assert [] = Jobs.list()
    end
  end

  describe "list/1" do
    test "applies the filters and the limit" do
      Mimic.expect(Repo, :all, fn query ->
        assert [
                 [[1, 2]],
                 [["scheduled"]],
                 [["default"]],
                 ["%Order%", false],
                 ["%Email%", true]
               ] = where_values(query)

        assert %{params: [{5, :integer}]} = query.limit

        []
      end)

      assert [] =
               Jobs.list(
                 ids: [1, 2],
                 states: ["scheduled"],
                 queues: ["default"],
                 workers: ["Order", "-Email"],
                 limit: 5
               )
    end

    test "ignores empty filters" do
      Mimic.expect(Repo, :all, fn query ->
        assert [] = query.wheres

        []
      end)

      assert [] = Jobs.list(ids: [], states: nil, queues: [], workers: [])
    end
  end

  describe "show_list/0" do
    setup do
      System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", "")
      System.put_env("OBAN_CONSOLE_JOBS_LAST_IDS", "")

      Storage.delete_profile_file()

      :ok
    end

    test "shows the list" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list()
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

    test "stores the listed jobs ids and opts" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      capture_io(fn -> Jobs.show_list(limit: 10, queues: ["default"]) end)

      assert [1, 2, 3, 4, 5, 6, 7] = Storage.get_last_jobs_ids()

      assert [ids: [], limit: 10, queues: ["default"], states: []] =
               Enum.sort(Storage.get_last_jobs_opts())
    end

    test "uses the last opts when called without opts" do
      Storage.set_last_jobs_opts(limit: 5, queues: ["searching"])
      stub_all(ObanMock.jobs())

      capture_io(fn -> Jobs.show_list() end)

      assert_received {:query, query}
      assert [[["searching"]]] = where_values(query)
      assert %{params: [{5, :integer}]} = query.limit
    end

    test "converts states numbers and groups" do
      stub_all([])

      capture_io(fn -> Jobs.show_list(states: ["1", "5", "failed", "7", "in_progress"]) end)

      states = [
        "available",
        "completed",
        "cancelled",
        "discarded",
        "cancelled",
        "available",
        "scheduled",
        "retryable",
        "executing"
      ]

      assert_received {:query, query}
      assert [[^states]] = where_values(query)
      assert ^states = Keyword.get(Storage.get_last_jobs_opts(), :states)
    end

    test "keeps unknown states as they are" do
      stub_all([])

      capture_io(fn -> Jobs.show_list(states: ["scheduled", "8"]) end)

      assert ["scheduled", "8"] = Keyword.get(Storage.get_last_jobs_opts(), :states)
    end

    test "with ids [0] filters by the jobs listed before" do
      Storage.set_last_jobs_ids([3, 4])
      stub_all([build(:job, id: 3), build(:job, id: 4)])

      capture_io(fn -> Jobs.show_list(ids: [0]) end)

      assert_received {:query, query}
      assert [[[3, 4]]] = where_values(query)
      assert [3, 4] = Storage.get_last_jobs_ids()
    end

    test "with ids filters by the given ids" do
      Storage.set_last_jobs_ids([3, 4])
      stub_all([build(:job, id: 1)])

      capture_io(fn -> Jobs.show_list(ids: [1]) end)

      assert_received {:query, query}
      assert [[[1]]] = where_values(query)
      assert [1] = Storage.get_last_jobs_ids()
    end

    test "on error prints it and shows the list without filters" do
      Mimic.expect(Repo, :all, fn _ -> raise "database error" end)
      stub_all(ObanMock.jobs())

      output = capture_io(fn -> Jobs.show_list(queues: ["default"]) end)

      assert output =~ "database error"
      assert_received {:query, query}
      assert [] = query.wheres
      assert [ids: [], limit: 20, states: []] = Enum.sort(Storage.get_last_jobs_opts())
    end
  end

  describe "clean_storage/0" do
    test "cleans the last opts" do
      Storage.set_last_jobs_opts(limit: 5)

      Jobs.clean_storage()

      assert [] = Storage.get_last_jobs_opts()
    end
  end

  describe "debug_jobs/1" do
    test "with an empty list of ids" do
      Mimic.reject(Repo, :get_job, 1)

      assert :ok = Jobs.debug_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :get_job, 2, fn id -> build(:job, id: id) end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs([1, 2]) end)

      assert output =~ "Job\e[0m | 1"
      assert output =~ "Job\e[0m | 2"
      assert output =~ "%Oban.Job{"
    end

    test "with a single id" do
      Mimic.expect(Repo, :get_job, fn 1 -> build(:job, id: 1, worker: "SendEmail") end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs(1) end)

      assert output =~ "Job\e[0m | 1"
      assert output =~ ~s(worker: "SendEmail")
    end

    test "with a job not found" do
      Mimic.expect(Repo, :get_job, fn 99 -> nil end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs(99) end)

      assert output =~ "Job\e[0m | 99 | Job not found"
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :get_job, 1)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs("abc") end)

      assert output =~ "Debug\e[0m | abc | Job ID is not valid"
    end
  end

  describe "retry_jobs/1" do
    test "with an empty list of ids" do
      Mimic.reject(Repo, :retry_job, 1)

      assert :ok = Jobs.retry_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :retry_job, 2, fn _ -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.retry_jobs([1, 2]) end)

      assert output =~ "Retried\e[0m | 1"
      assert output =~ "Retried\e[0m | 2"
    end

    test "with a single id" do
      Mimic.expect(Repo, :retry_job, fn 1 -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.retry_jobs(1) end)

      assert output =~ "Retried\e[0m | 1"
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :retry_job, 1)

      output = capture_io(fn -> assert :ok = Jobs.retry_jobs("abc") end)

      assert output =~ "Retry\e[0m | abc | Job ID is not valid"
    end
  end

  describe "cancel_jobs/1" do
    test "with an empty list of ids" do
      Mimic.reject(Repo, :cancel_job, 1)

      assert :ok = Jobs.cancel_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :cancel_job, 2, fn _ -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs([1, 2]) end)

      assert output =~ "Cancelled\e[0m | 1"
      assert output =~ "Cancelled\e[0m | 2"
    end

    test "with a single id" do
      Mimic.expect(Repo, :cancel_job, fn 1 -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs(1) end)

      assert output =~ "Cancelled\e[0m | 1"
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :cancel_job, 1)

      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs("abc") end)

      assert output =~ "Cancel\e[0m | abc | Job ID is not valid"
    end
  end

  defp where_values(query) do
    Enum.map(query.wheres, fn where -> Enum.map(where.params, &elem(&1, 0)) end)
  end

  # show_list/1 rescues every error and retries, so assertions must run outside of the mock.
  defp stub_all(result) do
    test_pid = self()

    Mimic.stub(Repo, :all, fn query ->
      send(test_pid, {:query, query})
      result
    end)
  end
end
