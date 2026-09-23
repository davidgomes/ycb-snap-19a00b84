defmodule Oban.Console.JobsTest do
  use ExUnit.Case

  alias Oban.Console.Jobs
  alias Oban.Console.Repo
  alias Oban.Console.Storage

  setup do
    Storage.set_last_jobs_opts([])
    Storage.set_last_jobs_ids([])

    :ok
  end

  describe "list/1" do
    test "returns the jobs from the repo" do
      Mimic.stub(Repo, :all, fn %Ecto.Query{} -> ObanConfigMock.jobs() end)

      assert ObanConfigMock.jobs() == Jobs.list()
    end

    test "accepts filters" do
      Mimic.stub(Repo, :all, fn %Ecto.Query{} = query ->
        assert query.limit
        assert length(query.wheres) == 4
        []
      end)

      assert [] =
               Jobs.list(
                 ids: [1],
                 states: ["available"],
                 queues: ["default"],
                 workers: ["Worker", "-Other"],
                 limit: 5
               )
    end
  end

  describe "show_list/1" do
    test "shows the list and stores the ids and opts" do
      Mimic.stub(Repo, :all, fn _ -> ObanConfigMock.jobs() end)

      assert :ok = Jobs.show_list(states: ["1", "in_progress"], limit: 10)

      assert Storage.get_last_jobs_ids() == Enum.map(ObanConfigMock.jobs(), & &1.id)

      opts = Storage.get_last_jobs_opts()
      assert opts[:limit] == 10

      assert opts[:states] == [
               "available",
               "available",
               "scheduled",
               "retryable",
               "executing"
             ]
    end

    test "shows an empty list" do
      Mimic.stub(Repo, :all, fn _ -> [] end)

      assert :ok = Jobs.show_list(states: ["failed"])
    end

    test "uses the last listed ids when ids is [0]" do
      Storage.set_last_jobs_ids([10, 20])

      Mimic.stub(Repo, :all, fn _ -> [] end)

      assert :ok = Jobs.show_list(ids: [0])
      assert Storage.get_last_jobs_opts()[:ids] == [10, 20]
    end
  end

  describe "clean_storage/0" do
    test "cleans the last opts" do
      Storage.set_last_jobs_opts(limit: 5)

      Jobs.clean_storage()

      assert Storage.get_last_jobs_opts() == []
    end
  end

  describe "debug_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.debug_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :get_job, 2, fn id -> %{id: id} end)

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
      assert :ok = Jobs.retry_jobs("a")
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
      assert :ok = Jobs.cancel_jobs("a")
    end
  end
end
