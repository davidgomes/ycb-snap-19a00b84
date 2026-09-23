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

    test "stores the listed job ids" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list()

      assert [1, 2, 3, 4, 5, 6, 7] = Storage.get_last_jobs_ids()
    end

    test "converts state aliases" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list(states: ["1", "failed"])
      assert ["available", "cancelled", "discarded"] = Storage.get_last_jobs_opts()[:states]

      assert :ok = Jobs.show_list(states: ["in_progress"])

      assert ["available", "scheduled", "retryable", "executing"] =
               Storage.get_last_jobs_opts()[:states]
    end

    test "with ids [0] uses the ids listed before" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      Storage.set_last_jobs_ids([2, 3])

      assert :ok = Jobs.show_list(ids: [0])
      assert [2, 3] = Storage.get_last_jobs_opts()[:ids]
    end

    test "reuses the last opts when called without opts" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list(limit: 5, queues: ["default"])
      assert :ok = Jobs.show_list()

      assert 5 = Storage.get_last_jobs_opts()[:limit]
      assert ["default"] = Storage.get_last_jobs_opts()[:queues]
    end
  end

  describe "clean_storage/0" do
    test "resets the last opts" do
      Storage.set_last_jobs_opts(limit: 5)

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

      assert :ok = Jobs.debug_jobs([1, 2])
    end

    test "with a job that doesn't exist" do
      Mimic.expect(Repo, :get_job, fn _ -> nil end)

      assert :ok = Jobs.debug_jobs(1)
    end

    test "with an invalid id" do
      assert :ok = Jobs.debug_jobs("invalid")
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
      assert :ok = Jobs.retry_jobs("invalid")
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
      assert :ok = Jobs.cancel_jobs("invalid")
    end
  end
end
