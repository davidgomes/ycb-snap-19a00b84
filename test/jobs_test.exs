defmodule Oban.Console.JobsTest do
  use ExUnit.Case

  alias Oban.Console.Jobs
  alias Oban.Console.Repo
  alias Oban.Console.Storage

  import Factory

  describe "list/0" do
    test "return jobs" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert ObanMock.jobs() == Jobs.list()
    end
  end

  describe "list/1" do
    test "with ids filter" do
      Mimic.expect(Repo, :all, fn query ->
        assert inspect(query) =~ "j0.id in ^[1, 2]"
        ObanMock.jobs()
      end)

      assert ObanMock.jobs() == Jobs.list(ids: [1, 2])
    end

    test "with states filter" do
      Mimic.expect(Repo, :all, fn query ->
        assert inspect(query) =~ "j0.state in ^[\"available\", \"executing\"]"
        ObanMock.jobs()
      end)

      assert ObanMock.jobs() == Jobs.list(states: ["available", "executing"])
    end

    test "with queues filter" do
      Mimic.expect(Repo, :all, fn query ->
        assert inspect(query) =~ "j0.queue in ^[\"default\"]"
        ObanMock.jobs()
      end)

      assert ObanMock.jobs() == Jobs.list(queues: ["default"])
    end

    test "with workers filter" do
      Mimic.expect(Repo, :all, fn query ->
        query_str = inspect(query)
        assert query_str =~ "like(j0.worker, ^\"%ProcessOrder%\")"
        assert query_str =~ "not like(j0.worker, ^\"%OtherWorker%\")"
        ObanMock.jobs()
      end)

      assert ObanMock.jobs() == Jobs.list(workers: ["ProcessOrder", "-OtherWorker"])
    end

    test "with limit" do
      Mimic.expect(Repo, :all, fn query ->
        assert inspect(query) =~ "limit: ^50"
        ObanMock.jobs()
      end)

      assert ObanMock.jobs() == Jobs.list(limit: 50)
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

    test "with state aliases and groups" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list(states: ["1", "in_progress", "failed", "custom"])

      opts = Storage.get_last_jobs_opts()
      assert Keyword.get(opts, :limit) == 20
      assert Keyword.get(opts, :ids) == []

      assert Keyword.get(opts, :states) == [
               "available",
               "available",
               "scheduled",
               "retryable",
               "executing",
               "cancelled",
               "discarded",
               "custom"
             ]
    end

    test "with ids [0] uses last jobs ids" do
      Storage.set_last_jobs_ids([10, 20])

      Mimic.expect(Repo, :all, fn query ->
        assert inspect(query) =~ "j0.id in ^[10, 20]"
        ObanMock.jobs()
      end)

      assert :ok = Jobs.show_list(ids: [0])
    end

    test "rescues error and retries with default opts" do
      Process.put(:fail_first, true)

      Mimic.expect(Repo, :all, 2, fn _query ->
        if Process.get(:fail_first) do
          Process.put(:fail_first, false)
          raise RuntimeError, "query error"
        else
          ObanMock.jobs()
        end
      end)

      assert :ok = Jobs.show_list(limit: 50)
    end
  end

  describe "clean_storage/0" do
    test "cleans storage options" do
      Storage.set_last_jobs_opts(limit: 50)
      assert :ok = Jobs.clean_storage()
      assert [] = Storage.get_last_jobs_opts()
    end
  end

  describe "debug_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.debug_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Oban, :config, 2, fn _name -> %Oban.Config{repo: Oban.Repo} end)
      Mimic.expect(Oban.Repo, :get, 2, fn _, Oban.Job, _id -> build(:job) end)

      assert :ok = Jobs.debug_jobs([1, 2])
    end

    test "with a single id" do
      Mimic.expect(Oban, :config, 1, fn _name -> %Oban.Config{repo: Oban.Repo} end)
      Mimic.expect(Oban.Repo, :get, 1, fn _, Oban.Job, 1 -> build(:job, id: 1) end)

      assert :ok = Jobs.debug_jobs(1)
    end

    test "with a single id when job is not found" do
      Mimic.expect(Oban, :config, 1, fn _name -> %Oban.Config{repo: Oban.Repo} end)
      Mimic.expect(Oban.Repo, :get, 1, fn _, Oban.Job, 999 -> nil end)

      assert :ok = Jobs.debug_jobs(999)
    end

    test "with an invalid id" do
      assert :ok = Jobs.debug_jobs("invalid")
      assert :ok = Jobs.debug_jobs(nil)
    end
  end

  describe "retry_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.retry_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Oban, :retry_job, 2, fn _id -> {:ok, build(:job)} end)

      assert :ok = Jobs.retry_jobs([1, 2])
    end

    test "with a single id" do
      Mimic.expect(Oban, :retry_job, 1, fn 1 -> {:ok, build(:job)} end)

      assert :ok = Jobs.retry_jobs(1)
    end

    test "with an invalid id" do
      assert :ok = Jobs.retry_jobs("invalid")
      assert :ok = Jobs.retry_jobs(nil)
    end
  end

  describe "cancel_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.cancel_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Oban, :cancel_job, 2, fn _id -> {:ok, build(:job)} end)

      assert :ok = Jobs.cancel_jobs([1, 2])
    end

    test "with a single id" do
      Mimic.expect(Oban, :cancel_job, 1, fn 1 -> {:ok, build(:job)} end)

      assert :ok = Jobs.cancel_jobs(1)
    end

    test "with an invalid id" do
      assert :ok = Jobs.cancel_jobs("invalid")
      assert :ok = Jobs.cancel_jobs(nil)
    end
  end
end
