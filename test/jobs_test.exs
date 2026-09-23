defmodule Oban.Console.JobsTest do
  use ExUnit.Case

  import ExUnit.CaptureIO
  import Mimic

  alias Oban.Console.Jobs
  alias Oban.Console.Repo
  alias Oban.Console.Storage

  setup :verify_on_exit!

  setup do
    System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", "")
    System.put_env("OBAN_CONSOLE_JOBS_LAST_IDS", "")
    System.put_env("OBAN_CONSOLE_PROFILE", "")

    Storage.delete_profile_file()

    :ok
  end

  defp capture_query(test_pid) do
    stub(Repo, :jobs, fn query ->
      send(test_pid, {:query, inspect(query, width: :infinity)})
      ObanConfigMock.jobs()
    end)
  end

  describe "list/1" do
    test "returns jobs" do
      jobs = ObanConfigMock.jobs()
      stub(Repo, :jobs, fn _ -> jobs end)

      assert ^jobs = Jobs.list()
    end

    test "limits by 20 without options" do
      capture_query(self())

      Jobs.list()

      assert_received {:query, query}
      assert query =~ "limit: 20"
      refute query =~ "where:"
    end

    test "filters by ids, states, queues and limit" do
      capture_query(self())

      Jobs.list(ids: [1, 2], states: ["available"], queues: ["default"], limit: 5)

      assert_received {:query, query}
      assert query =~ "j0.id in ^[1, 2]"
      assert query =~ ~s(j0.state in ^["available"])
      assert query =~ ~s(j0.queue in ^["default"])
      assert query =~ "limit: ^5"
    end

    test "filters by included and excluded workers" do
      capture_query(self())

      Jobs.list(workers: ["Matching", "-Searching"])

      assert_received {:query, query}
      assert query =~ ~s[like(j0.worker, ^"%Matching%")]
      assert query =~ ~s[not like(j0.worker, ^"%Searching%")]
    end

    test "ignores empty filters" do
      capture_query(self())

      Jobs.list(ids: [], states: nil, queues: [], workers: nil)

      assert_received {:query, query}
      refute query =~ "where:"
    end

    test "sorts by attempted_at and scheduled_at" do
      capture_query(self())

      Jobs.list()

      assert_received {:query, query}
      assert query =~ "desc: j0.attempted_at"
      assert query =~ "desc: j0.scheduled_at"
    end
  end

  describe "show_list/1" do
    test "shows the list and stores listed ids and options" do
      stub(Repo, :jobs, fn _ -> ObanConfigMock.jobs() end)

      output = capture_io(fn -> assert :ok = Jobs.show_list(queues: ["default"]) end)

      assert output =~ "Rows: 3"
      assert [1, 2, 3] = Storage.get_last_jobs_ids()

      opts = Storage.get_last_jobs_opts()
      assert ["default"] = Keyword.get(opts, :queues)
      assert 20 = Keyword.get(opts, :limit)
      assert [] = Keyword.get(opts, :ids)
      assert [] = Keyword.get(opts, :states)
    end

    test "shows no records found" do
      stub(Repo, :jobs, fn _ -> [] end)

      output = capture_io(fn -> assert :ok = Jobs.show_list(queues: ["default"]) end)

      assert output =~ "No records found"
      assert [] = Storage.get_last_jobs_ids()
    end

    test "converts state numbers and groups" do
      test_pid = self()

      stub(Repo, :jobs, fn query ->
        send(test_pid, {:wheres, query.wheres})
        []
      end)

      capture_io(fn -> Jobs.show_list(states: ["1", "failed", "in_progress", "completed"]) end)

      states = ~w[available cancelled discarded available scheduled retryable executing completed]

      assert_received {:wheres, [%{params: [{^states, _}]}]}
      assert ^states = Keyword.get(Storage.get_last_jobs_opts(), :states)
    end

    test "uses the last listed ids when ids is [0]" do
      Storage.set_last_jobs_ids([7, 8])
      capture_query(self())

      capture_io(fn -> Jobs.show_list(ids: [0]) end)

      assert_received {:query, query}
      assert query =~ "j0.id in ^[7, 8]"
    end

    test "uses the last options without options" do
      Storage.set_last_jobs_opts(queues: ["searching"], limit: 3)
      capture_query(self())

      capture_io(fn -> Jobs.show_list() end)

      assert_received {:query, query}
      assert query =~ ~s(j0.queue in ^["searching"])
      assert query =~ "limit: ^3"
    end

    test "accepts nil options" do
      capture_query(self())

      capture_io(fn ->
        assert :ok = Jobs.show_list(ids: nil, states: nil, queues: nil, workers: nil, limit: nil)
      end)

      assert_received {:query, query}
      assert query =~ "limit: ^20"
      refute query =~ "where:"
    end

    test "adds filters to the selected profile history" do
      stub(Repo, :jobs, fn _ -> ObanConfigMock.jobs() end)
      :ok = Storage.find_or_create_profile("search api", [])

      capture_io(fn -> Jobs.show_list(queues: ["default"]) end)

      assert {"search api", %{"filters" => [%{"queues" => ["default"]}]}} = Storage.get_profile()
    end

    test "resets the last options and lists again on error" do
      stub(Repo, :jobs, fn _ -> ObanConfigMock.jobs() end)
      expect(Repo, :jobs, fn _ -> raise "boom" end)

      output = capture_io(fn -> assert :ok = Jobs.show_list(queues: ["default"]) end)

      assert output =~ "boom"
      assert output =~ "Rows: 3"
      assert nil == Keyword.get(Storage.get_last_jobs_opts(), :queues)
    end
  end

  describe "clean_storage/0" do
    test "resets the last options" do
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
      expect(Repo, :get_job, 2, fn id -> Enum.find(ObanConfigMock.jobs(), &(&1.id == id)) end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs([1, 2]) end)

      assert output =~ "%Oban.Job{"
      assert output =~ "id: 1"
      assert output =~ "id: 2"
    end

    test "with a single id" do
      job = List.first(ObanConfigMock.jobs())
      expect(Repo, :get_job, fn 1 -> job end)

      output = capture_io(fn -> Jobs.debug_jobs(1) end)

      assert output =~ "%Oban.Job{"
    end

    test "with a job not found" do
      expect(Repo, :get_job, fn 99 -> nil end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs(99) end)

      assert output =~ "Job not found"
    end

    test "with an invalid id" do
      reject(Repo, :get_job, 1)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs("a") end)

      assert output =~ "Job ID is not valid"
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

      capture_io(fn -> assert :ok = Jobs.retry_jobs(1) end)
    end

    test "with an invalid id" do
      reject(Repo, :retry_job, 1)

      output = capture_io(fn -> assert :ok = Jobs.retry_jobs("a") end)

      assert output =~ "Job ID is not valid"
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

      capture_io(fn -> assert :ok = Jobs.cancel_jobs(1) end)
    end

    test "with an invalid id" do
      reject(Repo, :cancel_job, 1)

      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs("a") end)

      assert output =~ "Job ID is not valid"
    end
  end
end
