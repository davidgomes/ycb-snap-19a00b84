defmodule Oban.Console.JobsTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias Oban.Console.Jobs
  alias Oban.Console.Repo
  alias Oban.Console.Storage

  import Factory

  setup {Mimic, :verify_on_exit!}

  describe "list/0" do
    test "return jobs" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert ObanMock.jobs() == Jobs.list()
    end

    test "limits to 20 jobs by default" do
      Mimic.expect(Repo, :all, fn query ->
        assert inspect(query) =~ "limit: 20"
        []
      end)

      assert [] = Jobs.list()
    end
  end

  describe "list/1" do
    test "filters by the given options" do
      Mimic.expect(Repo, :all, fn query ->
        query = inspect(query)

        assert query =~ "limit: ^50"
        assert query =~ "j0.id in ^[1, 2]"
        assert query =~ "j0.state in ^[\"available\"]"
        assert query =~ "j0.queue in ^[\"default\"]"
        assert query =~ "like(j0.worker, ^\"%Process%\")"
        assert query =~ "not like(j0.worker, ^\"%Order%\")"

        [build(:job, id: 1)]
      end)

      assert [%Oban.Job{id: 1}] =
               Jobs.list(
                 ids: [1, 2],
                 states: ["available"],
                 queues: ["default"],
                 workers: ["Process", "-Order"],
                 limit: 50
               )
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

    test "saves the listed ids and the options used" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      capture_io(fn -> assert :ok = Jobs.show_list(limit: 50) end)

      assert [1, 2, 3, 4, 5, 6, 7] = Storage.get_last_jobs_ids()

      last_opts = Storage.get_last_jobs_opts()

      assert 50 == last_opts[:limit]
      assert [] == last_opts[:states]
      assert [] == last_opts[:ids]
    end

    test "uses the last options when none are given" do
      Mimic.stub(Repo, :all, fn _ -> [] end)

      Storage.set_last_jobs_opts(limit: 10, queues: ["default"])

      capture_io(fn -> assert :ok = Jobs.show_list() end)

      last_opts = Storage.get_last_jobs_opts()

      assert 10 == last_opts[:limit]
      assert ["default"] == last_opts[:queues]
    end

    test "converts state shortcuts" do
      Mimic.stub(Repo, :all, fn _ -> [] end)

      capture_io(fn -> assert :ok = Jobs.show_list(states: ["1", "7", "failed", "completed"]) end)

      assert ~w[available cancelled cancelled discarded completed] ==
               Storage.get_last_jobs_opts()[:states]

      capture_io(fn -> assert :ok = Jobs.show_list(states: ["in_progress"]) end)

      assert ~w[available scheduled retryable executing] == Storage.get_last_jobs_opts()[:states]
    end

    test "filters by the ids listed before when ids is [0]" do
      Mimic.stub(Repo, :all, fn _ -> [build(:job, id: 2)] end)

      Storage.set_last_jobs_ids([2, 3])

      capture_io(fn -> assert :ok = Jobs.show_list(ids: [0]) end)

      assert [2, 3] == Storage.get_last_jobs_opts()[:ids]
      assert [2] == Storage.get_last_jobs_ids()
    end

    test "shows the error and lists again without filters when it fails" do
      Mimic.expect(Repo, :all, fn _ -> raise "query failed" end)
      Mimic.expect(Repo, :all, fn _ -> ObanMock.jobs() end)

      output = capture_io(fn -> assert :ok = Jobs.show_list(limit: 50) end)

      assert output =~ "query failed"
      assert 20 == Storage.get_last_jobs_opts()[:limit]
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
    test "clears the last options" do
      Storage.set_last_jobs_opts(limit: 50)

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

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs([1, 2]) end)

      assert output =~ "Job\e[0m | 1"
      assert output =~ "Job\e[0m | 2"
      assert output =~ "%Oban.Job{"
    end

    test "with a single id" do
      Mimic.expect(Repo, :get_job, fn 1 -> build(:job, id: 1) end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs(1) end)

      assert output =~ "Job\e[0m | 1"
      assert output =~ "%Oban.Job{"
    end

    test "when the job is not found" do
      Mimic.expect(Repo, :get_job, fn 1 -> nil end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs(1) end)

      assert output =~ "Job\e[0m | 1 | Job not found"
    end

    test "with an invalid id" do
      output = capture_io(fn -> assert :ok = Jobs.debug_jobs("a") end)

      assert output =~ "Debug\e[0m | a | Job ID is not valid"
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
      output = capture_io(fn -> assert :ok = Jobs.retry_jobs("a") end)

      assert output =~ "Retry\e[0m | a | Job ID is not valid"
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
      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs("a") end)

      assert output =~ "Cancel\e[0m | a | Job ID is not valid"
    end
  end
end
