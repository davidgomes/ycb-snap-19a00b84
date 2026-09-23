defmodule Oban.Console.JobsTest do
  use ExUnit.Case

  import ExUnit.CaptureIO
  import Factory

  alias Oban.Console.Jobs
  alias Oban.Console.Repo
  alias Oban.Console.Storage
  alias Oban.Console.View.Printer

  setup {Mimic, :verify_on_exit!}

  setup do
    System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", "")
    System.put_env("OBAN_CONSOLE_JOBS_LAST_IDS", "")
    System.put_env("OBAN_CONSOLE_PROFILE", "")

    Storage.delete_profile_file()

    :ok
  end

  describe "list/1" do
    test "returns the jobs found" do
      jobs = build_list(2, :job)

      expect_listing(jobs)

      assert ^jobs = Jobs.list()
    end

    test "limits to 20 jobs by default" do
      assert list_query([]) =~ "limit: 20"
    end

    test "limits to the given number of jobs" do
      assert list_query(limit: 50) =~ "limit: ^50"
    end

    test "filters by ids" do
      assert list_query(ids: [1, 2]) =~ "where: j0.id in ^[1, 2]"
    end

    test "filters by states" do
      assert list_query(states: ["available", "completed"]) =~
               ~s(where: j0.state in ^["available", "completed"])
    end

    test "filters by queues" do
      assert list_query(queues: ["default", "searching"]) =~
               ~s(where: j0.queue in ^["default", "searching"])
    end

    test "filters by workers matching any of the given names" do
      assert list_query(workers: ["Mailer", "Billing"]) =~
               ~s[where: like(j0.worker, ^"%Mailer%") or (like(j0.worker, ^"%Billing%") or ^false)]
    end

    test "excludes workers matching the names prefixed with -" do
      assert list_query(workers: ["-Mailer", "-Billing"]) =~
               ~s[where: not like(j0.worker, ^"%Mailer%") and (not like(j0.worker, ^"%Billing%") and ^true)]
    end

    test "ignores empty filters" do
      refute list_query(ids: [], states: nil, queues: [], workers: nil) =~ "where:"
    end

    test "sorts by attempted_at and scheduled_at" do
      query = list_query([])

      assert query =~ "CASE WHEN attempted_at IS NULL"
      assert query =~ "order_by: [desc: j0.attempted_at], order_by: [desc: j0.scheduled_at]"
    end
  end

  describe "show_list/1" do
    test "shows the jobs found" do
      expect_listing([
        build(:job, id: 3, state: "completed"),
        build(:job, id: 5, worker: "MyApp.Workers.Billing")
      ])

      {result, output} = with_io(fn -> Jobs.show_list(queues: ["default"]) end)

      assert :ok = result
      assert output =~ ~s(Rows: 2 Filters: [limit: 20, queues: ["default"]])
      assert output =~ "MyApp.Workers.Mailer"
      assert output =~ "MyApp.Workers.Billing"
    end

    test "shows a message when no jobs are found" do
      expect_listing([])

      output = capture_io(fn -> Jobs.show_list(queues: ["default"]) end)

      assert output =~ "Rows: 0"
      assert output =~ "No records found"
    end

    test "stores the listed ids and the filters used" do
      expect_listing([build(:job, id: 3), build(:job, id: 5)])

      capture_io(fn -> Jobs.show_list(queues: ["default"], limit: 5) end)

      assert [3, 5] = Storage.get_last_jobs_ids()

      assert [ids: [], limit: 5, queues: ["default"], states: []] =
               Enum.sort(Storage.get_last_jobs_opts())
    end

    test "adds the filters to the selected profile history" do
      assert :ok = Storage.find_or_create_profile("search api", [])

      expect_listing([])

      capture_io(fn -> Jobs.show_list(queues: ["default"]) end)

      assert {"search api", %{"filters" => [filters]}} = Storage.get_profile()
      assert %{"queues" => ["default"], "limit" => 20} = filters
    end

    test "uses the last filters when none are given" do
      Storage.set_last_jobs_opts(queues: ["searching"], limit: 7)

      query = show_list_query([])

      assert query =~ ~s(where: j0.queue in ^["searching"])
      assert query =~ "limit: ^7"
    end

    test "filters by the ids listed before when ids is [0]" do
      Storage.set_last_jobs_ids([10, 11])

      assert show_list_query(ids: [0]) =~ "where: j0.id in ^[10, 11]"
    end

    test "limits to 20 jobs when the limit is nil" do
      assert show_list_query(limit: nil) =~ "limit: ^20"
    end

    test "converts state numbers into state names" do
      assert show_list_query(states: ["1", "2", "3", "4"]) =~
               ~s(where: j0.state in ^["available", "scheduled", "retryable", "executing"])

      assert show_list_query(states: ["5", "6", "7"]) =~
               ~s(where: j0.state in ^["completed", "discarded", "cancelled"])
    end

    test "expands the in_progress and failed states" do
      assert show_list_query(states: ["in_progress", "failed"]) =~
               ~s(where: j0.state in ^["available", "scheduled", "retryable", "executing", "cancelled", "discarded"])
    end

    test "keeps state names as given" do
      assert show_list_query(states: ["completed"]) =~ ~s(where: j0.state in ^["completed"])
    end

    test "shows the error and lists again without filters when listing fails" do
      Mimic.expect(Repo, :all, fn _query -> raise "connection refused" end)
      expect_listing([])

      output = capture_io(fn -> Jobs.show_list(queues: ["default"]) end)

      assert output =~ "connection refused"
      assert output =~ "No records found"

      assert_received {:listed, query}
      refute query =~ "where:"
      refute Keyword.has_key?(Storage.get_last_jobs_opts(), :queues)
    end
  end

  describe "clean_storage/0" do
    test "forgets the last filters used" do
      Storage.set_last_jobs_opts(states: ["available"], limit: 50)

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
      Mimic.expect(Repo, :get_job, fn 1 -> build(:job, id: 1) end)
      Mimic.expect(Repo, :get_job, fn 2 -> build(:job, id: 2) end)

      {result, output} = with_io(fn -> Jobs.debug_jobs([1, 2]) end)

      assert :ok = result
      assert output =~ Printer.title(["Job", 1])
      assert output =~ Printer.title(["Job", 2])
    end

    test "with a single id" do
      Mimic.expect(Repo, :get_job, fn 1 -> build(:job, id: 1, worker: "MyApp.Workers.Billing") end)

      output = capture_io(fn -> Jobs.debug_jobs(1) end)

      assert output =~ Printer.title(["Job", 1])
      assert output =~ ~s(worker: "MyApp.Workers.Billing")
    end

    test "with an id not found" do
      Mimic.expect(Repo, :get_job, fn 1 -> nil end)

      assert capture_io(fn -> Jobs.debug_jobs(1) end) =~
               Printer.title(["Job", 1, "Job not found"])
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :get_job, 1)

      assert capture_io(fn -> Jobs.debug_jobs("abc") end) =~
               Printer.title(["Debug", "abc", "Job ID is not valid"])
    end
  end

  describe "retry_jobs/1" do
    test "with an empty list of ids" do
      Mimic.reject(Repo, :retry_job, 1)

      assert :ok = Jobs.retry_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :retry_job, fn 1 -> :ok end)
      Mimic.expect(Repo, :retry_job, fn 2 -> :ok end)

      {result, output} = with_io(fn -> Jobs.retry_jobs([1, 2]) end)

      assert :ok = result
      assert output =~ Printer.title(["Retried", 1])
      assert output =~ Printer.title(["Retried", 2])
    end

    test "with a single id" do
      Mimic.expect(Repo, :retry_job, fn 1 -> :ok end)

      {result, output} = with_io(fn -> Jobs.retry_jobs(1) end)

      assert :ok = result
      assert output =~ Printer.title(["Retried", 1])
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :retry_job, 1)

      assert capture_io(fn -> Jobs.retry_jobs("abc") end) =~
               Printer.title(["Retry", "abc", "Job ID is not valid"])
    end
  end

  describe "cancel_jobs/1" do
    test "with an empty list of ids" do
      Mimic.reject(Repo, :cancel_job, 1)

      assert :ok = Jobs.cancel_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :cancel_job, fn 1 -> :ok end)
      Mimic.expect(Repo, :cancel_job, fn 2 -> :ok end)

      {result, output} = with_io(fn -> Jobs.cancel_jobs([1, 2]) end)

      assert :ok = result
      assert output =~ Printer.title(["Cancelled", 1])
      assert output =~ Printer.title(["Cancelled", 2])
    end

    test "with a single id" do
      Mimic.expect(Repo, :cancel_job, fn 1 -> :ok end)

      {result, output} = with_io(fn -> Jobs.cancel_jobs(1) end)

      assert :ok = result
      assert output =~ Printer.title(["Cancelled", 1])
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :cancel_job, 1)

      assert capture_io(fn -> Jobs.cancel_jobs("abc") end) =~
               Printer.title(["Cancel", "abc", "Job ID is not valid"])
    end
  end

  defp expect_listing(jobs) do
    Mimic.expect(Repo, :all, fn query ->
      send(self(), {:listed, inspect(query, width: :infinity)})

      jobs
    end)
  end

  defp list_query(opts) do
    expect_listing([])

    Jobs.list(opts)

    assert_received {:listed, query}
    query
  end

  defp show_list_query(opts) do
    expect_listing([])

    capture_io(fn -> Jobs.show_list(opts) end)

    assert_received {:listed, query}
    query
  end
end
