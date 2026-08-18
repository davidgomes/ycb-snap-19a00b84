defmodule Oban.Console.JobsTest do
  use ExUnit.Case

  alias Oban.Console.Jobs
  alias Oban.Console.Repo
  alias Oban.Console.Storage

  import Factory

  describe "list/0" do
    test "return jobs" do
      Mimic.stub(Repo, :all, fn _ -> ObanConfigMock.jobs() end)

      assert ObanConfigMock.jobs() == Jobs.list()
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
      Mimic.stub(Repo, :all, fn _ -> ObanConfigMock.jobs() end)

      assert :ok = Jobs.show_list()
    end

    test "with a profile shows list adding the opts to the profile" do
      Mimic.stub(Repo, :all, fn _ -> ObanConfigMock.jobs() end)

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

    test "recovers from an invalid stored filter by resetting it" do
      System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", "not valid json")

      Mimic.stub(Repo, :all, fn _ -> ObanConfigMock.jobs() end)

      assert :ok = Jobs.show_list()
      assert [] = Storage.get_last_jobs_opts()
    end
  end

  describe "clean_storage/0" do
    test "resets the stored jobs options" do
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
      job = build(:job, id: 1)
      Mimic.expect(Repo, :get_job, 2, fn _ -> job end)

      assert :ok = Jobs.debug_jobs([1, 2])
    end

    test "with a single id" do
      job = build(:job, id: 1)
      Mimic.stub(Repo, :get_job, fn _ -> job end)

      assert :ok = Jobs.debug_jobs(1)
    end

    test "when the job is not found" do
      Mimic.stub(Repo, :get_job, fn _ -> nil end)

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
      Mimic.expect(Repo, :retry_job, 1, fn _ -> :ok end)

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
      Mimic.expect(Repo, :cancel_job, 1, fn _ -> :ok end)

      assert :ok = Jobs.cancel_jobs(1)
    end

    test "with an invalid id" do
      assert :ok = Jobs.cancel_jobs("invalid")
    end
  end
end
