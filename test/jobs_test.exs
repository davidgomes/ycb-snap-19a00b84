defmodule Oban.Console.JobsTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias Oban.Console.Jobs
  alias Oban.Console.Repo
  alias Oban.Console.Storage

  import Factory

  setup {Mimic, :verify_on_exit!}

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

    test "applies filters to the query" do
      Mimic.expect(Repo, :all, fn query ->
        assert length(query.wheres) == 5
        assert query.limit != nil

        []
      end)

      assert [] =
               Jobs.list(
                 ids: [1, 2],
                 states: ["available"],
                 queues: ["default"],
                 workers: ["Process", "-Order"],
                 limit: 10
               )
    end
  end

  describe "show_list/0" do
    test "shows the list" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list()
    end

    test "stores the listed ids and opts" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      capture_io(fn -> assert :ok = Jobs.show_list(limit: 50) end)

      assert [1, 2, 3, 4, 5, 6, 7] = Storage.get_last_jobs_ids()

      opts = Storage.get_last_jobs_opts()
      assert 50 == Keyword.get(opts, :limit)
      assert [] == Keyword.get(opts, :ids)
      assert [] == Keyword.get(opts, :states)
    end

    test "reuses the last opts when called without opts" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      Storage.set_last_jobs_opts(limit: 5, states: ["completed"])

      capture_io(fn -> assert :ok = Jobs.show_list() end)

      opts = Storage.get_last_jobs_opts()
      assert 5 == Keyword.get(opts, :limit)
      assert ["completed"] == Keyword.get(opts, :states)
    end

    test "converts state shortcuts" do
      Mimic.stub(Repo, :all, fn _ -> [] end)

      capture_io(fn -> assert :ok = Jobs.show_list(states: ["1", "failed", "in_progress"]) end)

      assert ["available", "cancelled", "discarded", "available", "scheduled", "retryable", "executing"] ==
               Keyword.get(Storage.get_last_jobs_opts(), :states)
    end

    test "uses the last listed ids when ids is [0]" do
      Mimic.stub(Repo, :all, fn _ -> [build(:job, id: 3), build(:job, id: 5)] end)

      Storage.set_last_jobs_ids([3, 5])

      capture_io(fn -> assert :ok = Jobs.show_list(ids: [0]) end)

      assert [3, 5] == Keyword.get(Storage.get_last_jobs_opts(), :ids)
    end

    test "resets the opts and lists again when listing fails" do
      Mimic.expect(Repo, :all, fn _ -> raise "query failed" end)
      Mimic.expect(Repo, :all, fn _ -> ObanMock.jobs() end)

      output = capture_io(fn -> assert :ok = Jobs.show_list(limit: 50) end)

      assert output =~ "query failed"
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

  describe "clean_storage/0" do
    test "clears the last opts" do
      Storage.set_last_jobs_opts(limit: 50)

      Jobs.clean_storage()

      assert [] == Storage.get_last_jobs_opts()
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
      Mimic.expect(Repo, :get_job, fn 1 -> build(:job, id: 1) end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs(1) end)

      assert output =~ "Job\e[0m | 1"
      assert output =~ "%Oban.Job{"
    end

    test "with a job that does not exist" do
      Mimic.expect(Repo, :get_job, fn 1 -> nil end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs(1) end)

      assert output =~ "Job not found"
    end

    test "with an invalid id" do
      output = capture_io(fn -> assert :ok = Jobs.debug_jobs("abc") end)

      assert output =~ "Job ID is not valid"
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

      output = capture_io(fn -> assert :ok = Jobs.retry_jobs(1) end)

      assert output =~ "Retried\e[0m | 1"
    end

    test "with an invalid id" do
      output = capture_io(fn -> assert :ok = Jobs.retry_jobs("abc") end)

      assert output =~ "Job ID is not valid"
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

      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs(1) end)

      assert output =~ "Cancelled\e[0m | 1"
    end

    test "with an invalid id" do
      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs("abc") end)

      assert output =~ "Job ID is not valid"
    end
  end
end
