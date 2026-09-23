defmodule Oban.Console.JobsTest do
  use ExUnit.Case
  use Mimic

  import ExUnit.CaptureIO
  import Factory

  alias Oban.Console.Jobs
  alias Oban.Console.Repo
  alias Oban.Console.Storage

  setup do
    System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", "")
    System.put_env("OBAN_CONSOLE_JOBS_LAST_IDS", "")
    System.put_env("OBAN_CONSOLE_PROFILE", "")

    Storage.delete_profile_file()

    :ok
  end

  describe "list/1" do
    test "returns the jobs" do
      jobs = build_list(2, :job)

      expect_jobs(jobs)

      assert ^jobs = Jobs.list()
    end

    test "without filters limits to 20 jobs sorted by attempted_at and scheduled_at" do
      expect_jobs([])

      Jobs.list()

      query = listed_query()

      refute query =~ "where:"
      assert query =~ "order_by: [desc: j0.attempted_at]"
      assert query =~ "order_by: [desc: j0.scheduled_at]"
      assert query =~ "limit: 20"
    end

    test "filters by ids, states and queues" do
      expect_jobs([])

      Jobs.list(ids: [1, 2], states: ["available", "scheduled"], queues: ["default"])

      query = listed_query()

      assert query =~ "where: j0.id in ^[1, 2]"
      assert query =~ ~s(where: j0.state in ^["available", "scheduled"])
      assert query =~ ~s(where: j0.queue in ^["default"])
    end

    test "filters by workers including and excluding them" do
      expect_jobs([])

      Jobs.list(workers: ["Mailer", "-Sync"])

      query = listed_query()

      assert query =~ ~s{where: like(j0.worker, ^"%Mailer%")}
      assert query =~ ~s{where: not like(j0.worker, ^"%Sync%")}
    end

    test "limits by the given limit" do
      expect_jobs([])

      Jobs.list(limit: 5)

      assert listed_query() =~ "limit: ^5"
    end
  end

  describe "show_list/1" do
    test "shows the jobs" do
      expect_jobs([build(:job, worker: "MyApp.Mailer"), build(:job, worker: "MyApp.Sync")])

      output = capture_io(fn -> Jobs.show_list(limit: 5) end)

      assert output =~ "Rows: 2"
      assert output =~ "MyApp.Mailer"
      assert output =~ "MyApp.Sync"
    end

    test "shows a message when there are no jobs" do
      expect_jobs([])

      assert capture_io(fn -> Jobs.show_list(limit: 5) end) =~ "No records found"
    end

    test "stores the listed ids and the options" do
      expect_jobs([build(:job, id: 1), build(:job, id: 2)])

      capture_io(fn -> Jobs.show_list(states: ["available"], limit: 5) end)

      assert [1, 2] = Storage.get_last_jobs_ids()
      assert [ids: [], limit: 5, states: ["available"]] = Storage.get_last_jobs_opts()
    end

    test "adds the options to the selected profile filters history" do
      Storage.find_or_create_profile("search api", [])

      expect_jobs([])

      capture_io(fn -> Jobs.show_list(limit: 5) end)

      assert {"search api", %{"filters" => [%{"ids" => [], "limit" => 5, "states" => []}]}} =
               Storage.get_profile()
    end

    test "uses the last options when no options are given" do
      Storage.set_last_jobs_opts(queues: ["default"], limit: 5)

      expect_jobs([])

      capture_io(fn -> Jobs.show_list() end)

      query = listed_query()

      assert query =~ ~s(where: j0.queue in ^["default"])
      assert query =~ "limit: ^5"
    end

    test "limits to 20 jobs by default" do
      expect_jobs([])

      capture_io(fn -> Jobs.show_list(limit: nil) end)

      assert listed_query() =~ "limit: ^20"
    end

    test "converts states numbers to their names" do
      expect_jobs([])

      capture_io(fn -> Jobs.show_list(states: ["1", "5", "retryable"]) end)

      assert listed_query() =~ ~s(where: j0.state in ^["available", "completed", "retryable"])
    end

    test "converts in_progress and failed states" do
      expect_jobs([])

      capture_io(fn -> Jobs.show_list(states: ["in_progress", "failed"]) end)

      states = ~w[available scheduled retryable executing cancelled discarded]

      assert listed_query() =~ "where: j0.state in ^#{inspect(states)}"
    end

    test "filters by the last listed ids when ids is [0]" do
      Storage.set_last_jobs_ids([3, 4])

      expect_jobs([])

      capture_io(fn -> Jobs.show_list(ids: [0]) end)

      assert listed_query() =~ "where: j0.id in ^[3, 4]"
    end

    test "cleans the last options and lists again when listing fails" do
      Storage.set_last_jobs_opts(states: ["available"])

      Mimic.expect(Repo, :jobs, fn _query -> raise "Database unavailable" end)
      expect_jobs([build(:job, id: 1)])

      output = capture_io(fn -> Jobs.show_list() end)

      assert output =~ "Database unavailable"
      assert output =~ "Rows: 1"
      refute listed_query() =~ "where:"
      assert [ids: [], limit: 20, states: []] = Storage.get_last_jobs_opts()
    end
  end

  describe "clean_storage/0" do
    test "cleans the last options" do
      Storage.set_last_jobs_opts(states: ["available"], limit: 5)

      Jobs.clean_storage()

      assert [] = Storage.get_last_jobs_opts()
    end
  end

  describe "debug_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.debug_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :get_job, 2, fn id -> build(:job, id: id) end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs([1, 2]) end)

      assert output =~ "Job\e[0m | 1"
      assert output =~ "Job\e[0m | 2"
    end

    test "with a single id" do
      Mimic.expect(Repo, :get_job, fn 1 -> build(:job, id: 1, worker: "MyApp.Mailer") end)

      output = capture_io(fn -> Jobs.debug_jobs(1) end)

      assert output =~ "Job\e[0m | 1"
      assert output =~ "%Oban.Job{"
      assert output =~ ~s(worker: "MyApp.Mailer")
    end

    test "with a not found id" do
      Mimic.expect(Repo, :get_job, fn 1 -> nil end)

      assert capture_io(fn -> Jobs.debug_jobs(1) end) =~ "Job\e[0m | 1 | Job not found"
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :get_job, 1)

      assert capture_io(fn -> Jobs.debug_jobs("a") end) =~ "Debug\e[0m | a | Job ID is not valid"
    end
  end

  describe "retry_jobs/1" do
    test "with an empty list of ids" do
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

      assert capture_io(fn -> Jobs.retry_jobs(1) end) =~ "Retried\e[0m | 1"
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :retry_job, 1)

      assert capture_io(fn -> Jobs.retry_jobs("a") end) =~ "Retry\e[0m | a | Job ID is not valid"
    end
  end

  describe "cancel_jobs/1" do
    test "with an empty list of ids" do
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

      assert capture_io(fn -> Jobs.cancel_jobs(1) end) =~ "Cancelled\e[0m | 1"
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :cancel_job, 1)

      assert capture_io(fn -> Jobs.cancel_jobs("a") end) =~
               "Cancel\e[0m | a | Job ID is not valid"
    end
  end

  defp expect_jobs(jobs) do
    test_pid = self()

    Mimic.expect(Repo, :jobs, fn query ->
      send(test_pid, {:jobs_query, inspect(query)})
      jobs
    end)
  end

  defp listed_query() do
    assert_received {:jobs_query, query}

    query
  end
end
