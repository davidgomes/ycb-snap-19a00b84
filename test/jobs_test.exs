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

  describe "list/1" do
    test "forwards ids, states, queues, workers and limit as query filters" do
      Mimic.stub(Repo, :all, fn %Ecto.Query{} = query ->
        assert %Ecto.Query{from: %{source: {"oban_jobs", Oban.Job}}} = query
        assert length(query.wheres) == 4

        ObanMock.jobs()
      end)

      assert ObanMock.jobs() ==
               Jobs.list(
                 ids: [1, 2],
                 states: ["available"],
                 queues: ["default"],
                 workers: ["ProcessOrder"],
                 limit: 5
               )
    end

    test "with empty opts uses the default limit" do
      Mimic.stub(Repo, :all, fn %Ecto.Query{} = query ->
        assert Enum.empty?(query.wheres)

        ObanMock.jobs()
      end)

      assert ObanMock.jobs() == Jobs.list()
    end

    test "excludes workers matching a '-' prefixed pattern" do
      Mimic.stub(Repo, :all, fn %Ecto.Query{} = query ->
        assert length(query.wheres) == 1

        ObanMock.jobs()
      end)

      assert ObanMock.jobs() == Jobs.list(workers: ["-ProcessOrder"])
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

      :ok
    end

    test "converts numeric state codes into their state names" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list(states: ["1", "6"])

      assert Keyword.get(Storage.get_last_jobs_opts(), :states) == ["available", "discarded"]
    end

    test "expands the in_progress state group" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list(states: ["in_progress"])

      assert Keyword.get(Storage.get_last_jobs_opts(), :states) ==
               ~w[available scheduled retryable executing]
    end

    test "expands the failed state group" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list(states: ["failed"])

      assert Keyword.get(Storage.get_last_jobs_opts(), :states) == ~w[cancelled discarded]
    end

    test "reuses the last shown ids when ids is [0]" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      Storage.set_last_jobs_ids([10, 20, 30])

      assert :ok = Jobs.show_list(ids: [0])

      assert Keyword.get(Storage.get_last_jobs_opts(), :ids) == [10, 20, 30]
    end

    test "resets ids to an empty list when ids is nil" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list(ids: nil)

      assert Keyword.get(Storage.get_last_jobs_opts(), :ids) == []
    end

    test "keeps explicit ids untouched" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list(ids: [5, 6])

      assert Keyword.get(Storage.get_last_jobs_opts(), :ids) == [5, 6]
    end

    test "falls back to the default limit when limit is nil" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list(limit: nil)

      assert Keyword.get(Storage.get_last_jobs_opts(), :limit) == 20
    end

    test "recovers from a repo error by resetting the filters and retrying" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      Mimic.stub(Repo, :all, fn _ ->
        if Agent.get_and_update(counter, &{&1, &1 + 1}) == 0 do
          raise "boom"
        else
          ObanMock.jobs()
        end
      end)

      Storage.set_last_jobs_opts(limit: 999)

      output =
        capture_io(fn ->
          assert :ok = Jobs.show_list()
        end)

      assert output =~ "boom"
      assert Keyword.get(Storage.get_last_jobs_opts(), :limit) == 20
    end
  end

  describe "clean_storage/0" do
    setup do
      System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", "")

      :ok
    end

    test "resets the last jobs opts" do
      Storage.set_last_jobs_opts(limit: 50)

      assert :ok = Jobs.clean_storage()
      assert [] = Storage.get_last_jobs_opts()
    end
  end

  describe "debug_jobs/1" do
    test "with an empty list does nothing" do
      assert :ok = Jobs.debug_jobs([])
    end

    test "with a job id that exists prints the job" do
      job = build(:job, id: 1)

      Mimic.stub(Oban, :config, fn Oban -> %Oban.Config{} end)
      Mimic.stub(Oban.Repo, :get, fn _conf, Oban.Job, 1 -> job end)

      output = capture_io(fn -> Jobs.debug_jobs(1) end)

      assert output =~ "Job"
      assert output =~ inspect(job)
    end

    test "with a job id that does not exist prints not found" do
      Mimic.stub(Oban, :config, fn Oban -> %Oban.Config{} end)
      Mimic.stub(Oban.Repo, :get, fn _conf, Oban.Job, 404 -> nil end)

      output = capture_io(fn -> Jobs.debug_jobs(404) end)

      assert output =~ "Job not found"
    end

    test "with a list of job ids debugs each one" do
      jobs = %{1 => build(:job, id: 1), 2 => build(:job, id: 2)}

      Mimic.stub(Oban, :config, fn Oban -> %Oban.Config{} end)
      Mimic.stub(Oban.Repo, :get, fn _conf, Oban.Job, id -> Map.fetch!(jobs, id) end)

      output = capture_io(fn -> Jobs.debug_jobs([1, 2]) end)

      assert output =~ inspect(jobs[1])
      assert output =~ inspect(jobs[2])
    end

    test "with an invalid job id prints an error" do
      output = capture_io(fn -> Jobs.debug_jobs("abc") end)

      assert output =~ "Job ID is not valid"
    end
  end

  describe "retry_jobs/1" do
    test "with an empty list does nothing" do
      assert :ok = Jobs.retry_jobs([])
    end

    test "with a job id retries the job" do
      Mimic.expect(Oban, :retry_job, fn 1 -> :ok end)

      output = capture_io(fn -> Jobs.retry_jobs(1) end)

      assert output =~ "Retried"
      assert output =~ "1"
    end

    test "with a list of job ids retries each one" do
      Mimic.expect(Oban, :retry_job, 2, fn id when id in [1, 2] -> :ok end)

      output = capture_io(fn -> Jobs.retry_jobs([1, 2]) end)

      assert output =~ "Retried"
    end

    test "with an invalid job id prints an error" do
      output = capture_io(fn -> Jobs.retry_jobs("abc") end)

      assert output =~ "Job ID is not valid"
    end
  end

  describe "cancel_jobs/1" do
    test "with an empty list does nothing" do
      assert :ok = Jobs.cancel_jobs([])
    end

    test "with a job id cancels the job" do
      Mimic.expect(Oban, :cancel_job, fn 1 -> :ok end)

      output = capture_io(fn -> Jobs.cancel_jobs(1) end)

      assert output =~ "Cancelled"
      assert output =~ "1"
    end

    test "with a list of job ids cancels each one" do
      Mimic.expect(Oban, :cancel_job, 2, fn id when id in [1, 2] -> :ok end)

      output = capture_io(fn -> Jobs.cancel_jobs([1, 2]) end)

      assert output =~ "Cancelled"
    end

    test "with an invalid job id prints an error" do
      output = capture_io(fn -> Jobs.cancel_jobs("abc") end)

      assert output =~ "Job ID is not valid"
    end
  end
end
