defmodule Oban.Console.JobsTest do
  use ExUnit.Case
  import Factory

  alias Oban.Console.Jobs
  alias Oban.Console.Repo
  alias Oban.Console.Storage

  describe "list/1" do
    test "returns jobs from repo" do
      jobs = ObanConfigMock.jobs()
      Mimic.stub(Repo, :all_jobs, fn _opts -> jobs end)

      assert ^jobs = Jobs.list()
    end

    test "passes options to repo" do
      opts = [states: ["available"], limit: 10]

      Mimic.expect(Repo, :all_jobs, fn received_opts ->
        assert received_opts == opts
        []
      end)

      Jobs.list(opts)
    end
  end

  describe "show_list/1" do
    setup do
      System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", "")
      System.put_env("OBAN_CONSOLE_JOBS_LAST_IDS", "")
      Storage.delete_profile_file()
      :ok
    end

    test "displays jobs in a table and stores last opts and ids" do
      job1 = build(:job, id: 10, worker: "WorkerA", state: "available")
      job2 = build(:job, id: 20, worker: "WorkerB", state: "executing")
      jobs = [job1, job2]

      Mimic.stub(Repo, :all_jobs, fn _opts -> jobs end)

      assert :ok = Jobs.show_list(states: ["1", "4"], limit: 10)
      assert [10, 20] == Storage.get_last_jobs_ids()
      stored_opts = Storage.get_last_jobs_opts()
      assert Keyword.get(stored_opts, :limit) == 10
      assert Keyword.get(stored_opts, :states) == ["available", "executing"]
      assert Keyword.get(stored_opts, :ids) == []
    end

    test "uses stored opts when opts is empty" do
      Storage.set_last_jobs_opts(limit: 5, states: ["scheduled"])
      Mimic.stub(Repo, :all_jobs, fn _opts -> [] end)

      assert :ok = Jobs.show_list([])
      stored_opts = Storage.get_last_jobs_opts()
      assert Keyword.get(stored_opts, :limit) == 5
    end

    test "handles 'in_progress' and 'failed' pseudo-states" do
      Mimic.stub(Repo, :all_jobs, fn opts ->
        assert Keyword.get(opts, :states) == ["available", "scheduled", "retryable", "executing"]
        []
      end)

      Jobs.show_list(states: ["in_progress"])
    end

    test "handles [0] for ids to reuse previous ids" do
      Storage.set_last_jobs_ids([101, 102])

      Mimic.stub(Repo, :all_jobs, fn opts ->
        assert Keyword.get(opts, :ids) == [101, 102]
        []
      end)

      Jobs.show_list(ids: [0])
    end

    test "rescues exceptions, clears stored opts and retries" do
      count = :atomics.new(1, [])
      :atomics.put(count, 1, 0)

      Mimic.stub(Repo, :all_jobs, fn _opts ->
        val = :atomics.add_get(count, 1, 1)

        if val == 1 do
          raise "Boom!"
        else
          []
        end
      end)

      assert :ok = Jobs.show_list()
    end
  end

  describe "clean_storage/0" do
    test "clears stored job options" do
      Storage.set_last_jobs_opts(limit: 10, states: ["available"])
      Jobs.clean_storage()
      assert [] = Storage.get_last_jobs_opts()
    end
  end

  describe "debug_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.debug_jobs([])
    end

    test "with a list of ids" do
      job1 = build(:job, id: 1)
      job2 = build(:job, id: 2)
      Mimic.expect(Repo, :get_job, 1, fn 1 -> job1 end)
      Mimic.expect(Repo, :get_job, 1, fn 2 -> job2 end)

      assert :ok = Jobs.debug_jobs([1, 2])
    end

    test "with a single existing job id" do
      job = build(:job, id: 1)
      Mimic.expect(Repo, :get_job, 1, fn 1 -> job end)

      assert ^job = Jobs.debug_jobs(1)
    end

    test "with a single non-existing job id" do
      Mimic.expect(Repo, :get_job, 1, fn 999 -> nil end)

      assert :ok = Jobs.debug_jobs(999)
    end

    test "with an invalid job id" do
      assert :ok = Jobs.debug_jobs("not_an_id")
    end
  end

  describe "retry_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.retry_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :retry_job, 1, fn 1 -> {:ok, build(:job, id: 1)} end)
      Mimic.expect(Repo, :retry_job, 1, fn 2 -> {:ok, build(:job, id: 2)} end)

      assert :ok = Jobs.retry_jobs([1, 2])
    end

    test "with a single id" do
      Mimic.expect(Repo, :retry_job, 1, fn 1 -> {:ok, build(:job, id: 1)} end)

      assert :ok = Jobs.retry_jobs(1)
    end

    test "with an invalid id" do
      assert :ok = Jobs.retry_jobs("invalid")
    end
  end

  describe "cancel_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.cancel_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :cancel_job, 1, fn 1 -> {:ok, build(:job, id: 1)} end)
      Mimic.expect(Repo, :cancel_job, 1, fn 2 -> {:ok, build(:job, id: 2)} end)

      assert :ok = Jobs.cancel_jobs([1, 2])
    end

    test "with a single id" do
      Mimic.expect(Repo, :cancel_job, 1, fn 1 -> {:ok, build(:job, id: 1)} end)

      assert :ok = Jobs.cancel_jobs(1)
    end

    test "with an invalid id" do
      assert :ok = Jobs.cancel_jobs("invalid")
    end
  end
end
