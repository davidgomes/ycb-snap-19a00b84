defmodule Oban.Console.JobsTest do
  use ExUnit.Case

  import ExUnit.CaptureIO
  import Factory

  alias Oban.Console.Jobs
  alias Oban.Console.Repo
  alias Oban.Console.Storage

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

  describe "clean_storage/0" do
    test "clears the last jobs options" do
      Storage.set_last_jobs_opts(limit: 50, states: ["scheduled"])

      assert :ok = Jobs.clean_storage()
      assert [] = Storage.get_last_jobs_opts()
    end
  end

  describe "debug_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.debug_jobs([])
    end

    test "with a list of ids" do
      Mimic.stub(Oban, :config, fn Oban -> :oban_config end)

      Mimic.expect(Oban.Repo, :get, 2, fn :oban_config, Oban.Job, id ->
        build(:job, id: id)
      end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs([1, 2]) end)

      assert output =~ "id: 1"
      assert output =~ "id: 2"
    end

    test "with a single id" do
      job = build(:job, id: 1)

      Mimic.stub(Oban, :config, fn Oban -> :oban_config end)
      Mimic.expect(Oban.Repo, :get, fn :oban_config, Oban.Job, 1 -> job end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs(1) end)

      assert output =~ inspect(job)
    end

    test "when the job is not found" do
      Mimic.stub(Oban, :config, fn Oban -> :oban_config end)
      Mimic.expect(Oban.Repo, :get, fn :oban_config, Oban.Job, 1 -> nil end)

      assert capture_io(fn -> Jobs.debug_jobs(1) end) =~ "Job not found"
    end

    test "with an invalid id" do
      output = capture_io(fn -> assert :ok = Jobs.debug_jobs("invalid") end)

      assert output =~ "Debug"
      assert output =~ "Job ID is not valid"
    end
  end

  describe "retry_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.retry_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Oban, :retry_job, 2, fn id when id in [1, 2] -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.retry_jobs([1, 2]) end)

      assert output =~ "Retried"
      assert output =~ " | 1"
      assert output =~ " | 2"
    end

    test "with a single id" do
      Mimic.expect(Oban, :retry_job, fn 1 -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.retry_jobs(1) end)

      assert output =~ "Retried"
      assert output =~ " | 1"
    end

    test "with an invalid id" do
      output = capture_io(fn -> assert :ok = Jobs.retry_jobs("invalid") end)

      assert output =~ "Retry"
      assert output =~ "Job ID is not valid"
    end
  end

  describe "cancel_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.cancel_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Oban, :cancel_job, 2, fn id when id in [1, 2] -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs([1, 2]) end)

      assert output =~ "Cancelled"
      assert output =~ " | 1"
      assert output =~ " | 2"
    end

    test "with a single id" do
      Mimic.expect(Oban, :cancel_job, fn 1 -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs(1) end)

      assert output =~ "Cancelled"
      assert output =~ " | 1"
    end

    test "with an invalid id" do
      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs("invalid") end)

      assert output =~ "Cancel"
      assert output =~ "Job ID is not valid"
    end
  end
end
