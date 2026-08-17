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
  end

  describe "debug_jobs/1" do
    test "with an empty list of job ids" do
      assert :ok = Jobs.debug_jobs([])
    end

    test "with a list of job ids" do
      Mimic.expect(Oban.Repo, :get, 2, fn Oban.Job, _id -> build(:job, id: 1) end)

      assert :ok = Jobs.debug_jobs([1, 2])
    end

    test "with a single valid job id" do
      Mimic.expect(Oban.Repo, :get, 1, fn Oban.Job, 1 -> build(:job, id: 1) end)

      assert :ok = Jobs.debug_jobs(1)
    end

    test "with a job id that is not found" do
      Mimic.expect(Oban.Repo, :get, 1, fn Oban.Job, 999 -> nil end)

      assert :ok = Jobs.debug_jobs(999)
    end

    test "with an invalid job id" do
      assert :ok = Jobs.debug_jobs("invalid")
    end
  end

  describe "retry_jobs/1" do
    test "with an empty list of job ids" do
      assert :ok = Jobs.retry_jobs([])
    end

    test "with a list of job ids" do
      Mimic.expect(Oban, :retry_job, 2, fn _id -> {:ok, %Oban.Job{}} end)

      assert :ok = Jobs.retry_jobs([1, 2])
    end

    test "with a single valid job id" do
      Mimic.expect(Oban, :retry_job, 1, fn 1 -> {:ok, %Oban.Job{}} end)

      assert :ok = Jobs.retry_jobs(1)
    end

    test "with an invalid job id" do
      assert :ok = Jobs.retry_jobs("invalid")
    end
  end

  describe "cancel_jobs/1" do
    test "with an empty list of job ids" do
      assert :ok = Jobs.cancel_jobs([])
    end

    test "with a list of job ids" do
      Mimic.expect(Oban, :cancel_job, 2, fn _id -> {:ok, %Oban.Job{}} end)

      assert :ok = Jobs.cancel_jobs([1, 2])
    end

    test "with a single valid job id" do
      Mimic.expect(Oban, :cancel_job, 1, fn 1 -> {:ok, %Oban.Job{}} end)

      assert :ok = Jobs.cancel_jobs(1)
    end

    test "with an invalid job id" do
      assert :ok = Jobs.cancel_jobs("invalid")
    end
  end

  describe "clean_storage/0" do
    test "cleans storage options" do
      Storage.set_last_jobs_opts(states: ["scheduled"], limit: 50)

      assert :ok = Jobs.clean_storage()
      assert [] = Storage.get_last_jobs_opts()
    end
  end
end
