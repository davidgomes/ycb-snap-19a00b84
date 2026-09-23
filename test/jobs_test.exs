defmodule Oban.Console.JobsTest do
  use ExUnit.Case

  alias Oban.Console.Jobs
  alias Oban.Console.Repo
  alias Oban.Console.Storage

  import Factory
  import Mimic

  setup :verify_on_exit!

  describe "list/0" do
    test "return jobs" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert ObanMock.jobs() == Jobs.list()
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

    test "uses the last opts when opts are empty" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      Storage.set_last_jobs_opts(limit: 50, states: ["scheduled"])

      assert :ok = Jobs.show_list()

      opts = Storage.get_last_jobs_opts()

      assert 50 == Keyword.get(opts, :limit)
      assert ["scheduled"] == Keyword.get(opts, :states)
    end

    test "converts state aliases" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list(states: ["in_progress", "failed", "5", "custom"])

      assert ~w[available scheduled retryable executing cancelled discarded completed custom] ==
               Keyword.get(Storage.get_last_jobs_opts(), :states)
    end

    test "uses the ids listed before when ids is [0]" do
      Mimic.stub(Repo, :all, fn _ -> [build(:job, id: 2), build(:job, id: 5)] end)

      Storage.set_last_jobs_ids([2, 5])

      assert :ok = Jobs.show_list(ids: [0])

      assert [2, 5] == Keyword.get(Storage.get_last_jobs_opts(), :ids)
    end

    test "saves the listed job ids" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list(limit: 5)

      assert [1, 2, 3, 4, 5, 6, 7] == Storage.get_last_jobs_ids()
    end

    test "resets the last opts and lists again when listing fails" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)
      Mimic.expect(Repo, :all, fn _ -> raise "boom" end)

      assert :ok = Jobs.show_list(limit: 5)

      assert 20 == Keyword.get(Storage.get_last_jobs_opts(), :limit)
    end
  end

  describe "clean_storage/0" do
    test "resets the last opts" do
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

      assert :ok = Jobs.debug_jobs([1, 2])
    end

    test "with a single id" do
      Mimic.expect(Repo, :get_job, fn 1 -> build(:job, id: 1) end)

      assert :ok = Jobs.debug_jobs(1)
    end

    test "with a job not found" do
      Mimic.expect(Repo, :get_job, fn 1 -> nil end)

      assert :ok = Jobs.debug_jobs(1)
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :get_job, 1)

      assert :ok = Jobs.debug_jobs("1")
    end
  end

  describe "retry_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.retry_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :retry_job, 2, fn _ -> :ok end)

      assert :ok = Jobs.retry_jobs([1, 2])
    end

    test "with a single id" do
      Mimic.expect(Repo, :retry_job, fn 1 -> :ok end)

      assert :ok = Jobs.retry_jobs(1)
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :retry_job, 1)

      assert :ok = Jobs.retry_jobs("1")
    end
  end

  describe "cancel_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.cancel_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :cancel_job, 2, fn _ -> :ok end)

      assert :ok = Jobs.cancel_jobs([1, 2])
    end

    test "with a single id" do
      Mimic.expect(Repo, :cancel_job, fn 1 -> :ok end)

      assert :ok = Jobs.cancel_jobs(1)
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :cancel_job, 1)

      assert :ok = Jobs.cancel_jobs("1")
    end
  end
end
