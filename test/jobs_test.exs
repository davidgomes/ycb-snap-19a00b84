defmodule Oban.Console.JobsTest do
  use ExUnit.Case

  import ExUnit.CaptureIO
  import Factory

  alias Oban.Console.Jobs
  alias Oban.Console.Repo
  alias Oban.Console.Storage
  alias Oban.Console.View.Printer

  setup {Mimic, :verify_on_exit!}

  describe "list/0" do
    test "return jobs" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert ObanMock.jobs() == Jobs.list()
    end
  end

  describe "list/1" do
    setup do
      Mimic.stub(Repo, :all, fn query -> query end)

      :ok
    end

    test "without filters limits to 20 jobs sorted by attempted_at and scheduled_at" do
      query = inspect(Jobs.list())

      refute query =~ "where:"
      assert query =~ "order_by: [desc: j0.attempted_at], order_by: [desc: j0.scheduled_at]"
      assert query =~ "limit: 20"
    end

    test "filters by ids, states and queues with the given limit" do
      query = inspect(Jobs.list(ids: [1, 2], states: ["available"], queues: ["default"], limit: 5))

      assert query =~ ~s(where: j0.id in ^[1, 2])
      assert query =~ ~s(where: j0.state in ^["available"])
      assert query =~ ~s(where: j0.queue in ^["default"])
      assert query =~ "limit: ^5"
    end

    test "ignores empty filters" do
      query = inspect(Jobs.list(ids: [], states: nil, queues: [], workers: nil))

      refute query =~ "where:"
    end

    test "filters workers including them and excluding the ones prefixed by -" do
      query = inspect(Jobs.list(workers: ["Order", "-Payment"]))

      assert query =~ ~s{where: like(j0.worker, ^"%Order%")}
      assert query =~ ~s{where: not like(j0.worker, ^"%Payment%")}
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

  describe "show_list/1" do
    setup do
      System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", "")
      System.put_env("OBAN_CONSOLE_JOBS_LAST_IDS", "")

      Storage.delete_profile_file()

      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      :ok
    end

    test "saves the listed job ids and the opts" do
      capture_io(fn -> assert :ok = Jobs.show_list(queues: ["default"], limit: 10) end)

      assert [1, 2, 3, 4, 5, 6, 7] = Storage.get_last_jobs_ids()

      assert %{ids: [], states: [], queues: ["default"], limit: 10} ==
               Map.new(Storage.get_last_jobs_opts())
    end

    test "shows the jobs with the filters in the title" do
      output = capture_io(fn -> Jobs.show_list(queues: ["default"], limit: 10) end)

      assert output =~ "Rows: 7"
      assert output =~ ~s(queues: ["default"])

      for job <- ObanMock.jobs() do
        assert output =~ job.state
      end
    end

    test "shows a message when there are no jobs" do
      Mimic.stub(Repo, :all, fn _ -> [] end)

      output = capture_io(fn -> assert :ok = Jobs.show_list(limit: 10) end)

      assert output =~ "Rows: 0"
      assert output =~ "No records found"
      assert [] = Storage.get_last_jobs_ids()
    end

    test "converts the state numbers to state names" do
      capture_io(fn -> Jobs.show_list(states: ["1", "2", "3", "4", "5", "6", "7"]) end)

      assert ~w[available scheduled retryable executing completed discarded cancelled] ==
               Storage.get_last_jobs_opts()[:states]
    end

    test "converts the in_progress and failed states to their state names" do
      capture_io(fn -> Jobs.show_list(states: ["in_progress", "failed"]) end)

      assert ~w[available scheduled retryable executing cancelled discarded] ==
               Storage.get_last_jobs_opts()[:states]
    end

    test "keeps the state names" do
      capture_io(fn -> Jobs.show_list(states: ["completed", "3"]) end)

      assert ["completed", "retryable"] == Storage.get_last_jobs_opts()[:states]
    end

    test "uses the ids listed before when ids is [0]" do
      Storage.set_last_jobs_ids([3, 4])

      capture_io(fn -> Jobs.show_list(ids: [0]) end)

      assert [3, 4] == Storage.get_last_jobs_opts()[:ids]
    end

    test "uses the last opts when opts are empty" do
      Storage.set_last_jobs_opts(states: ["completed"], limit: 5)

      capture_io(fn -> Jobs.show_list([]) end)

      assert %{ids: [], states: ["completed"], limit: 5} == Map.new(Storage.get_last_jobs_opts())
    end

    test "defaults the limit to 20 when it's nil" do
      capture_io(fn -> Jobs.show_list(limit: nil) end)

      assert 20 == Storage.get_last_jobs_opts()[:limit]
    end

    test "cleans the last opts and lists again when listing fails" do
      Mimic.expect(Repo, :all, fn _ -> raise "listing failed" end)

      output = capture_io(fn -> assert :ok = Jobs.show_list(states: ["completed"], limit: 5) end)

      assert output =~ "listing failed"
      assert %{ids: [], states: [], limit: 20} == Map.new(Storage.get_last_jobs_opts())
    end
  end

  describe "clean_storage/0" do
    test "cleans the last opts" do
      Storage.set_last_jobs_opts(states: ["completed"], limit: 5)

      Jobs.clean_storage()

      assert [] = Storage.get_last_jobs_opts()
    end
  end

  describe "debug_jobs/1" do
    test "with an empty list of ids" do
      Mimic.reject(Repo, :get_job, 1)

      assert :ok = Jobs.debug_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :get_job, 2, fn id when id in [1, 2] -> build(:job, id: id) end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs([1, 2]) end)

      assert output =~ Printer.title(["Job", 1])
      assert output =~ inspect(build(:job, id: 1))
      assert output =~ Printer.title(["Job", 2])
      assert output =~ inspect(build(:job, id: 2))
    end

    test "with an id" do
      job = build(:job, id: 1)

      Mimic.expect(Repo, :get_job, fn 1 -> job end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs(1) end)

      assert output =~ Printer.title(["Job", 1])
      assert output =~ inspect(job)
    end

    test "with an id of a job that doesn't exist" do
      Mimic.expect(Repo, :get_job, fn 8 -> nil end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs(8) end)

      assert output =~ Printer.title(["Job", 8, "Job not found"])
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :get_job, 1)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs("one") end)

      assert output =~ Printer.title(["Debug", "one", "Job ID is not valid"])
    end
  end

  describe "retry_jobs/1" do
    test "with an empty list of ids" do
      Mimic.reject(Repo, :retry_job, 1)

      assert :ok = Jobs.retry_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :retry_job, 2, fn id when id in [1, 2] -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.retry_jobs([1, 2]) end)

      assert output =~ Printer.title(["Retried", 1])
      assert output =~ Printer.title(["Retried", 2])
    end

    test "with an id" do
      Mimic.expect(Repo, :retry_job, fn 1 -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.retry_jobs(1) end)

      assert output =~ Printer.title(["Retried", 1])
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :retry_job, 1)

      output = capture_io(fn -> assert :ok = Jobs.retry_jobs("one") end)

      assert output =~ Printer.title(["Retry", "one", "Job ID is not valid"])
    end
  end

  describe "cancel_jobs/1" do
    test "with an empty list of ids" do
      Mimic.reject(Repo, :cancel_job, 1)

      assert :ok = Jobs.cancel_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :cancel_job, 2, fn id when id in [1, 2] -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs([1, 2]) end)

      assert output =~ Printer.title(["Cancelled", 1])
      assert output =~ Printer.title(["Cancelled", 2])
    end

    test "with an id" do
      Mimic.expect(Repo, :cancel_job, fn 1 -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs(1) end)

      assert output =~ Printer.title(["Cancelled", 1])
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :cancel_job, 1)

      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs("one") end)

      assert output =~ Printer.title(["Cancel", "one", "Job ID is not valid"])
    end
  end
end
