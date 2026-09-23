defmodule Oban.Console.JobsTest do
  use ExUnit.Case

  import ExUnit.CaptureIO
  import Factory

  alias Oban.Console.Jobs
  alias Oban.Console.Repo
  alias Oban.Console.Storage
  alias Oban.Console.View.Printer

  setup {Mimic, :verify_on_exit!}

  describe "list/1" do
    test "return jobs" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert ObanMock.jobs() == Jobs.list()
    end

    test "limits to 20 jobs by default" do
      assert list_query([]) =~ "limit: 20"
    end

    test "ignores empty filters" do
      refute list_query(ids: [], states: nil, queues: [], workers: []) =~ "where:"
    end

    test "filters by ids, states, queues and limit" do
      query = list_query(ids: [1, 2], states: ["available"], queues: ["default"], limit: 5)

      assert query =~ "where: j0.id in ^[1, 2]"
      assert query =~ ~s(where: j0.state in ^["available"])
      assert query =~ ~s(where: j0.queue in ^["default"])
      assert query =~ "limit: ^5"
    end

    test "filters by workers excluding the ones prefixed with -" do
      query = list_query(workers: ["Order", "-Invoice"])

      assert query =~ ~s[where: like(j0.worker, ^"%Order%")]
      assert query =~ ~s[where: not like(j0.worker, ^"%Invoice%")]
    end
  end

  describe "show_list/1" do
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

    test "saves the listed jobs ids" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list(limit: 50)

      assert [1, 2, 3, 4, 5, 6, 7] = Storage.get_last_jobs_ids()
    end

    test "without opts reuses the last opts" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      Storage.set_last_jobs_opts(limit: 5, queues: ["default"])

      assert :ok = Jobs.show_list()

      last_opts = Storage.get_last_jobs_opts()

      assert 5 = last_opts[:limit]
      assert ["default"] = last_opts[:queues]
    end

    test "converts the states numbers and groups" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list(states: ["1", "failed", "in_progress", "completed"])

      assert [
               "available",
               "cancelled",
               "discarded",
               "available",
               "scheduled",
               "retryable",
               "executing",
               "completed"
             ] = Storage.get_last_jobs_opts()[:states]
    end

    test "with ids [0] filters by the jobs ids listed before" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      Storage.set_last_jobs_ids([3, 4])

      assert :ok = Jobs.show_list(ids: [0])

      assert [3, 4] = Storage.get_last_jobs_opts()[:ids]
    end

    test "without jobs found" do
      Mimic.stub(Repo, :all, fn _ -> [] end)

      assert capture_io(fn -> assert :ok = Jobs.show_list() end) =~ "No records found"
      assert [] = Storage.get_last_jobs_ids()
    end

    test "when listing fails resets the last opts and lists again" do
      Repo
      |> Mimic.expect(:all, fn _ -> raise "connection refused" end)
      |> Mimic.expect(:all, fn _ -> ObanMock.jobs() end)

      assert capture_io(fn -> assert :ok = Jobs.show_list(limit: 5) end) =~ "connection refused"
      assert 20 = Storage.get_last_jobs_opts()[:limit]
    end
  end

  describe "clean_storage/0" do
    test "resets the last opts" do
      Storage.set_last_jobs_opts(limit: 50, states: ["scheduled"])

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

      assert output =~ Printer.title(["Job", 1])
      assert output =~ Printer.title(["Job", 2])
    end

    test "with a single id" do
      Mimic.expect(Repo, :get_job, fn 1 -> build(:job, id: 1, worker: "SendEmail") end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs(1) end)

      assert output =~ Printer.title(["Job", 1])
      assert output =~ "%Oban.Job{"
      assert output =~ ~s(worker: "SendEmail")
    end

    test "with a job not found" do
      Mimic.expect(Repo, :get_job, fn 1 -> nil end)

      assert capture_io(fn -> assert :ok = Jobs.debug_jobs(1) end) =~
               Printer.title(["Job", 1, "Job not found"])
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :get_job, 1)

      assert capture_io(fn -> assert :ok = Jobs.debug_jobs("abc") end) =~
               Printer.title(["Debug", "abc", "Job ID is not valid"])
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

      assert output =~ Printer.title(["Retried", 1])
      assert output =~ Printer.title(["Retried", 2])
    end

    test "with a single id" do
      Mimic.expect(Repo, :retry_job, fn 1 -> :ok end)

      assert capture_io(fn -> assert :ok = Jobs.retry_jobs(1) end) =~
               Printer.title(["Retried", 1])
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :retry_job, 1)

      assert capture_io(fn -> assert :ok = Jobs.retry_jobs("abc") end) =~
               Printer.title(["Retry", "abc", "Job ID is not valid"])
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

      assert output =~ Printer.title(["Cancelled", 1])
      assert output =~ Printer.title(["Cancelled", 2])
    end

    test "with a single id" do
      Mimic.expect(Repo, :cancel_job, fn 1 -> :ok end)

      assert capture_io(fn -> assert :ok = Jobs.cancel_jobs(1) end) =~
               Printer.title(["Cancelled", 1])
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :cancel_job, 1)

      assert capture_io(fn -> assert :ok = Jobs.cancel_jobs("abc") end) =~
               Printer.title(["Cancel", "abc", "Job ID is not valid"])
    end
  end

  defp list_query(opts) do
    Mimic.expect(Repo, :all, fn query ->
      send(self(), {:query, query})

      []
    end)

    Jobs.list(opts)

    assert_received {:query, query}

    inspect(query)
  end
end
