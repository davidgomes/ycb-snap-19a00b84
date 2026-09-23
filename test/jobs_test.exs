defmodule Oban.Console.JobsTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

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

    test "stores the default opts and the listed ids" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list()

      assert [ids: [], limit: 20, states: []] = Storage.get_last_jobs_opts()
      assert [1, 2, 3, 4, 5, 6, 7] = Storage.get_last_jobs_ids()
    end

    test "without opts uses the last opts" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      Storage.set_last_jobs_opts(limit: 5, states: ["completed"])

      assert :ok = Jobs.show_list()

      assert [ids: [], limit: 5, states: ["completed"]] = Storage.get_last_jobs_opts()
    end

    test "converts the in_progress state" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list(states: ["in_progress"])

      assert ~w[available scheduled retryable executing] ==
               Keyword.get(Storage.get_last_jobs_opts(), :states)
    end

    test "converts the failed state" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list(states: ["failed"])

      assert ~w[cancelled discarded] == Keyword.get(Storage.get_last_jobs_opts(), :states)
    end

    test "converts numeric states and keeps named states" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list(states: ["1", "5", "7", "scheduled"])

      assert ~w[available completed cancelled scheduled] ==
               Keyword.get(Storage.get_last_jobs_opts(), :states)
    end

    test "with ids [0] filters by the last listed ids" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      Storage.set_last_jobs_ids([2, 3])

      assert :ok = Jobs.show_list(ids: [0])

      assert [2, 3] == Keyword.get(Storage.get_last_jobs_opts(), :ids)
    end

    test "with ids filters by the given ids" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list(ids: [4, 5])

      assert [4, 5] == Keyword.get(Storage.get_last_jobs_opts(), :ids)
    end

    test "with a custom limit" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list(limit: 100)

      assert 100 == Keyword.get(Storage.get_last_jobs_opts(), :limit)
    end

    test "on error prints it, resets the opts and shows the default list" do
      Repo
      |> Mimic.expect(:all, fn _ -> raise "invalid query" end)
      |> Mimic.expect(:all, fn _ -> ObanMock.jobs() end)

      output = capture_io(fn -> assert :ok = Jobs.show_list(limit: 50, states: ["completed"]) end)

      assert output =~ "invalid query"
      assert [ids: [], limit: 20, states: []] = Storage.get_last_jobs_opts()
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
    test "resets the last opts" do
      Storage.set_last_jobs_opts(limit: 50, states: ["scheduled"])

      Jobs.clean_storage()

      assert [] = Storage.get_last_jobs_opts()
    end
  end

  describe "debug_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.debug_jobs([])
    end

    test "with a list of ids" do
      Mimic.stub(Repo, :get_job, fn id -> build(:job, id: id) end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs([1, 2]) end)

      assert output =~ "| 1"
      assert output =~ "| 2"
      assert output =~ "Oban.Job"
    end

    test "with a single id" do
      Mimic.expect(Repo, :get_job, fn 1 -> build(:job, id: 1) end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs(1) end)

      assert output =~ "| 1"
      assert output =~ "ProcessOrder"
    end

    test "with a job not found" do
      Mimic.expect(Repo, :get_job, fn 99 -> nil end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs(99) end)

      assert output =~ "| 99 | Job not found"
    end

    test "with an invalid id" do
      output = capture_io(fn -> assert :ok = Jobs.debug_jobs("abc") end)

      assert output =~ "| abc | Job ID is not valid"
    end
  end

  describe "retry_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.retry_jobs([])
    end

    test "with a list of ids" do
      test_pid = self()

      Mimic.stub(Repo, :retry_job, fn id ->
        send(test_pid, {:retried, id})
        :ok
      end)

      output = capture_io(fn -> assert :ok = Jobs.retry_jobs([1, 2]) end)

      assert_received {:retried, 1}
      assert_received {:retried, 2}
      assert output =~ "Retried"
    end

    test "with a single id" do
      Mimic.expect(Repo, :retry_job, fn 1 -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.retry_jobs(1) end)

      assert output =~ "Retried"
      assert output =~ "| 1"
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :retry_job, 1)

      output = capture_io(fn -> assert :ok = Jobs.retry_jobs("abc") end)

      assert output =~ "| abc | Job ID is not valid"
    end
  end

  describe "cancel_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.cancel_jobs([])
    end

    test "with a list of ids" do
      test_pid = self()

      Mimic.stub(Repo, :cancel_job, fn id ->
        send(test_pid, {:cancelled, id})
        :ok
      end)

      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs([1, 2]) end)

      assert_received {:cancelled, 1}
      assert_received {:cancelled, 2}
      assert output =~ "Cancelled"
    end

    test "with a single id" do
      Mimic.expect(Repo, :cancel_job, fn 1 -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs(1) end)

      assert output =~ "Cancelled"
      assert output =~ "| 1"
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :cancel_job, 1)

      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs("abc") end)

      assert output =~ "| abc | Job ID is not valid"
    end
  end
end
