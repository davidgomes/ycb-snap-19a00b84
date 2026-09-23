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

  defp stub_jobs(jobs) do
    test_pid = self()

    stub(Repo, :jobs, fn query ->
      send(test_pid, {:query, query})
      jobs
    end)
  end

  defp received_query do
    assert_received {:query, %Ecto.Query{} = query}
    inspect(query)
  end

  describe "list/1" do
    test "returns the jobs from the repo" do
      jobs = build_list(2, :job)
      stub_jobs(jobs)

      assert ^jobs = Jobs.list()
    end

    test "limits to 20 jobs and sorts by attempted_at and scheduled_at by default" do
      stub_jobs([])

      Jobs.list()

      query = received_query()

      assert query =~ "limit: 20"
      assert query =~ "desc: j0.attempted_at"
      assert query =~ "desc: j0.scheduled_at"
      refute query =~ "where:"
    end

    test "filters by ids, states and queues" do
      stub_jobs([])

      Jobs.list(ids: [1, 2], states: ["available"], queues: ["default"], limit: 5)

      query = received_query()

      assert query =~ "j0.id in ^[1, 2]"
      assert query =~ ~s(j0.state in ^["available"])
      assert query =~ ~s(j0.queue in ^["default"])
      assert query =~ "limit: ^5"
    end

    test "ignores empty filters" do
      stub_jobs([])

      Jobs.list(ids: [], states: nil, queues: [], workers: nil)

      refute received_query() =~ "where:"
    end

    test "filters by included and excluded workers" do
      stub_jobs([])

      Jobs.list(workers: ["Search", "-Matching"])

      query = received_query()

      assert query =~ ~s[like(j0.worker, ^"%Search%")]
      assert query =~ ~s[not like(j0.worker, ^"%Matching%")]
    end
  end

  describe "show_list/1" do
    test "shows the jobs and stores the listed ids and options" do
      [%{id: id1}, %{id: id2}] = jobs = build_list(2, :job)
      stub_jobs(jobs)

      output = capture_io(fn -> assert :ok = Jobs.show_list(limit: 10) end)

      assert output =~ "Rows: 2"
      assert output =~ "MyApp.Workers.DefaultWorker"
      assert [^id1, ^id2] = Storage.get_last_jobs_ids()
      assert 10 = Keyword.get(Storage.get_last_jobs_opts(), :limit)
    end

    test "shows a message when there are no jobs" do
      stub_jobs([])

      assert capture_io(fn -> Jobs.show_list() end) =~ "No records found"
      assert [] = Storage.get_last_jobs_ids()
    end

    test "converts state numbers and aliases" do
      stub_jobs([])

      capture_io(fn -> Jobs.show_list(states: ["1", "failed"]) end)

      assert received_query() =~ ~s(j0.state in ^["available", "cancelled", "discarded"])
    end

    test "converts the in_progress state alias" do
      stub_jobs([])

      capture_io(fn -> Jobs.show_list(states: ["in_progress"]) end)

      assert received_query() =~
               ~s(j0.state in ^["available", "scheduled", "retryable", "executing"])
    end

    test "uses the last options when none are given" do
      Storage.set_last_jobs_opts(queues: ["searching"], limit: 7)
      stub_jobs([])

      capture_io(fn -> Jobs.show_list() end)

      query = received_query()

      assert query =~ ~s(j0.queue in ^["searching"])
      assert query =~ "limit: ^7"
    end

    test "uses the last listed ids when ids is [0]" do
      Storage.set_last_jobs_ids([3, 4])
      stub_jobs([])

      capture_io(fn -> Jobs.show_list(ids: [0]) end)

      assert received_query() =~ "j0.id in ^[3, 4]"
    end

    test "adds the filters to the selected profile history" do
      Storage.find_or_create_profile("search api", [])
      stub_jobs([])

      capture_io(fn -> Jobs.show_list(queues: ["default"]) end)

      assert {"search api", %{"filters" => [%{"queues" => ["default"], "limit" => 20}]}} =
               Storage.get_profile()
    end
  end

  describe "clean_storage/0" do
    test "clears the last options" do
      Storage.set_last_jobs_opts(limit: 50)

      Jobs.clean_storage()

      assert [] = Storage.get_last_jobs_opts()
    end
  end

  describe "debug_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.debug_jobs([])
    end

    test "with a list of ids" do
      expect(Repo, :get_job, 2, fn id -> build(:job, id: id) end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs([1, 2]) end)

      assert output =~ "%Oban.Job{"
      assert output =~ "id: 1"
      assert output =~ "id: 2"
    end

    test "with a single id" do
      expect(Repo, :get_job, fn 1 -> build(:job, id: 1) end)

      assert capture_io(fn -> Jobs.debug_jobs(1) end) =~ "%Oban.Job{"
    end

    test "with a job not found" do
      expect(Repo, :get_job, fn 1 -> nil end)

      assert capture_io(fn -> Jobs.debug_jobs(1) end) =~ "Job not found"
    end

    test "with an invalid id" do
      reject(&Repo.get_job/1)

      assert capture_io(fn -> Jobs.debug_jobs("a") end) =~ "Job ID is not valid"
    end
  end

  describe "retry_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.retry_jobs([])
    end

    test "with a list of ids" do
      expect(Repo, :retry_job, 2, fn _ -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.retry_jobs([1, 2]) end)

      assert output =~ "Retried"
    end

    test "with a single id" do
      expect(Repo, :retry_job, fn 1 -> :ok end)

      assert capture_io(fn -> Jobs.retry_jobs(1) end) =~ "Retried"
    end

    test "with an invalid id" do
      reject(&Repo.retry_job/1)

      assert capture_io(fn -> Jobs.retry_jobs("a") end) =~ "Job ID is not valid"
    end
  end

  describe "cancel_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.cancel_jobs([])
    end

    test "with a list of ids" do
      expect(Repo, :cancel_job, 2, fn _ -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs([1, 2]) end)

      assert output =~ "Cancelled"
    end

    test "with a single id" do
      expect(Repo, :cancel_job, fn 1 -> :ok end)

      assert capture_io(fn -> Jobs.cancel_jobs(1) end) =~ "Cancelled"
    end

    test "with an invalid id" do
      reject(&Repo.cancel_job/1)

      assert capture_io(fn -> Jobs.cancel_jobs("a") end) =~ "Job ID is not valid"
    end
  end
end
