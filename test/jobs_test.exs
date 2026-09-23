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
    test "returns the jobs found" do
      jobs = build_list(2, :job)

      Mimic.stub(Repo, :all, fn _ -> jobs end)

      assert ^jobs = Jobs.list()
    end

    test "without filters limits to 20 jobs" do
      expect_query()

      Jobs.list()

      assert_received {:query, query}
      refute query =~ "where:"
      assert query =~ "limit: 20"
    end

    test "ignores empty filters" do
      expect_query()

      Jobs.list(ids: [], states: nil, queues: [], workers: nil)

      assert_received {:query, query}
      refute query =~ "where:"
    end

    test "filters by ids, states and queues" do
      expect_query()

      Jobs.list(ids: [1, 2], states: ["available", "scheduled"], queues: ["default"])

      assert_received {:query, query}
      assert query =~ "where: j0.id in ^[1, 2]"
      assert query =~ ~s|where: j0.state in ^["available", "scheduled"]|
      assert query =~ ~s|where: j0.queue in ^["default"]|
    end

    test "filters by workers including and excluding by name" do
      expect_query()

      Jobs.list(workers: ["Mailer", "-Report"])

      assert_received {:query, query}
      assert query =~ ~s|where: like(j0.worker, ^"%Mailer%")|
      assert query =~ ~s|where: not like(j0.worker, ^"%Report%")|
    end

    test "limits the jobs" do
      expect_query()

      Jobs.list(limit: 5)

      assert_received {:query, query}
      assert query =~ "limit: ^5"
    end
  end

  describe "show_list/1" do
    setup :reset_storage

    test "shows the jobs and stores the listed ids and options" do
      expect_query([
        build(:job, id: 1, worker: "MyApp.Mailer"),
        build(:job, id: 2, worker: "MyApp.Report")
      ])

      output = capture_io(fn -> assert :ok = Jobs.show_list(queues: ["default"], limit: 5) end)

      assert output =~ "Rows: 2"
      assert output =~ "MyApp.Mailer"
      assert output =~ "MyApp.Report"

      assert [1, 2] = Storage.get_last_jobs_ids()
      assert ["default"] = Storage.get_last_jobs_opts()[:queues]
      assert 5 = Storage.get_last_jobs_opts()[:limit]
    end

    test "shows a message when no jobs are found" do
      expect_query([])

      output = capture_io(fn -> assert :ok = Jobs.show_list(limit: 5) end)

      assert output =~ "No records found"
      assert [] = Storage.get_last_jobs_ids()
    end

    test "limits to 20 jobs when the limit is empty" do
      expect_query()

      capture_io(fn -> Jobs.show_list(limit: nil) end)

      assert_received {:query, query}
      assert query =~ "limit: ^20"
      assert 20 = Storage.get_last_jobs_opts()[:limit]
    end

    test "converts state numbers into state names" do
      expect_query()

      capture_io(fn -> Jobs.show_list(states: ["1", "5", "7"]) end)

      assert_received {:query, query}
      assert query =~ ~s|where: j0.state in ^["available", "completed", "cancelled"]|
    end

    test "converts state groups into state names" do
      expect_query()

      capture_io(fn -> Jobs.show_list(states: ["in_progress", "failed"]) end)

      assert_received {:query, query}

      assert query =~
               ~s|where: j0.state in ^["available", "scheduled", "retryable", "executing", "cancelled", "discarded"]|
    end

    test "filters by the ids listed before when ids is [0]" do
      Storage.set_last_jobs_ids([3, 4])

      expect_query()

      capture_io(fn -> Jobs.show_list(ids: [0]) end)

      assert_received {:query, query}
      assert query =~ "where: j0.id in ^[3, 4]"
    end

    test "uses the last options when called without options" do
      Storage.set_last_jobs_opts(queues: ["mailers"], limit: 7)

      expect_query()

      capture_io(fn -> Jobs.show_list() end)

      assert_received {:query, query}
      assert query =~ ~s|where: j0.queue in ^["mailers"]|
      assert query =~ "limit: ^7"
    end

    test "resets the last options and lists again when listing fails" do
      Storage.set_last_jobs_opts(queues: ["mailers"])

      Mimic.expect(Repo, :all, fn _ -> raise "listing failed" end)
      expect_query()

      output = capture_io(fn -> assert :ok = Jobs.show_list() end)

      assert output =~ "listing failed"
      assert output =~ "No records found"

      assert_received {:query, query}
      refute query =~ "where:"
      assert nil == Storage.get_last_jobs_opts()[:queues]
    end
  end

  describe "clean_storage/0" do
    setup :reset_storage

    test "removes the last options" do
      Storage.set_last_jobs_opts(queues: ["mailers"], limit: 7)

      Jobs.clean_storage()

      assert [] = Storage.get_last_jobs_opts()
    end
  end

  describe "debug_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.debug_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :get_job, 2, fn id when id in [1, 2] -> build(:job, id: id) end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs([1, 2]) end)

      assert output =~ Printer.title(["Job", 1])
      assert output =~ Printer.title(["Job", 2])
    end

    test "with a job found" do
      Mimic.expect(Repo, :get_job, fn 1 -> build(:job, id: 1, worker: "MyApp.Mailer") end)

      output = capture_io(fn -> Jobs.debug_jobs(1) end)

      assert output =~ Printer.title(["Job", 1])
      assert output =~ ~s|worker: "MyApp.Mailer"|
    end

    test "with a job not found" do
      Mimic.expect(Repo, :get_job, fn 1 -> nil end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs(1) end)

      assert output =~ Printer.title(["Job", 1, "Job not found"])
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :get_job, 1)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs("abc") end)

      assert output =~ Printer.title(["Debug", "abc", "Job ID is not valid"])
    end
  end

  describe "retry_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.retry_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :retry_job, 2, fn id when id in [1, 2] -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.retry_jobs([1, 2]) end)

      assert output =~ Printer.title(["Retried", 1])
      assert output =~ Printer.title(["Retried", 2])
    end

    test "with a single id" do
      Mimic.expect(Repo, :retry_job, fn 1 -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.retry_jobs(1) end)

      assert output =~ Printer.title(["Retried", 1])
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :retry_job, 1)

      output = capture_io(fn -> assert :ok = Jobs.retry_jobs("abc") end)

      assert output =~ Printer.title(["Retry", "abc", "Job ID is not valid"])
    end
  end

  describe "cancel_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.cancel_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :cancel_job, 2, fn id when id in [1, 2] -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs([1, 2]) end)

      assert output =~ Printer.title(["Cancelled", 1])
      assert output =~ Printer.title(["Cancelled", 2])
    end

    test "with a single id" do
      Mimic.expect(Repo, :cancel_job, fn 1 -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs(1) end)

      assert output =~ Printer.title(["Cancelled", 1])
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :cancel_job, 1)

      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs("abc") end)

      assert output =~ Printer.title(["Cancel", "abc", "Job ID is not valid"])
    end
  end

  defp expect_query(jobs \\ []) do
    test_pid = self()

    Mimic.expect(Repo, :all, fn query ->
      send(test_pid, {:query, inspect(query, width: :infinity)})
      jobs
    end)
  end

  defp reset_storage(_context) do
    System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", "")
    System.put_env("OBAN_CONSOLE_JOBS_LAST_IDS", "")
    System.put_env("OBAN_CONSOLE_PROFILE", "")

    Storage.delete_profile_file()

    :ok
  end
end
