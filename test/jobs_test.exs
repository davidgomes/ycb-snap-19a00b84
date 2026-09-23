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

    test "filters by converted states" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list(states: ["1", "in_progress", "failed"])

      assert Storage.get_last_jobs_opts()[:states] == [
               "available",
               "available",
               "scheduled",
               "retryable",
               "executing",
               "cancelled",
               "discarded"
             ]
    end

    test "stores the listed job ids" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list(limit: 10)
      assert Storage.get_last_jobs_ids() == [1, 2, 3, 4, 5, 6, 7]
    end
  end

  describe "debug_jobs/1" do
    test "with an empty list" do
      assert :ok = Jobs.debug_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :get_job, 2, fn id -> build(:job, id: id) end)

      assert :ok = Jobs.debug_jobs([1, 2])
    end

    test "with a job not found" do
      Mimic.expect(Repo, :get_job, fn _ -> nil end)

      assert :ok = Jobs.debug_jobs(1)
    end

    test "with an invalid id" do
      assert :ok = Jobs.debug_jobs("a")
    end
  end

  describe "retry_jobs/1" do
    test "with an empty list" do
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
      assert :ok = Jobs.retry_jobs("a")
    end
  end

  describe "cancel_jobs/1" do
    test "with an empty list" do
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
      assert :ok = Jobs.cancel_jobs("a")
    end
  end
end
