defmodule Oban.Console.JobsTest do
  use ExUnit.Case

  alias Oban.Console.Jobs
  alias Oban.Console.Repo
  alias Oban.Console.Storage

  setup do
    System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", "")
    System.put_env("OBAN_CONSOLE_JOBS_LAST_IDS", "")
    System.put_env("OBAN_CONSOLE_PROFILE", "")

    Storage.delete_profile_file()

    :ok
  end

  describe "list/1" do
    test "returns the jobs found" do
      Mimic.stub(Repo, :all, fn _ -> ObanConfigMock.jobs() end)

      assert ObanConfigMock.jobs() == Jobs.list()
    end

    test "filters by ids, states, queues, workers and limit" do
      Mimic.expect(Repo, :all, fn _ -> [] end)

      assert [] ==
               Jobs.list(
                 ids: [1, 2],
                 states: ["available"],
                 queues: ["default"],
                 workers: ["Default", "-Search"],
                 limit: 5
               )
    end
  end

  describe "show_list/1" do
    test "shows the list" do
      Mimic.stub(Repo, :all, fn _ -> ObanConfigMock.jobs() end)

      assert :ok = Jobs.show_list()
    end

    test "shows an empty list" do
      Mimic.stub(Repo, :all, fn _ -> [] end)

      assert :ok = Jobs.show_list()
    end

    test "stores the listed ids and the used options" do
      Mimic.stub(Repo, :all, fn _ -> ObanConfigMock.jobs() end)

      assert :ok = Jobs.show_list(states: ["1"], limit: 5)

      assert [1, 2, 3] == Storage.get_last_jobs_ids()

      opts = Storage.get_last_jobs_opts()

      assert ["available"] == Keyword.get(opts, :states)
      assert 5 == Keyword.get(opts, :limit)
    end

    test "reuses the last used options when none are given" do
      Mimic.stub(Repo, :all, fn _ -> ObanConfigMock.jobs() end)

      Storage.set_last_jobs_opts(states: ["executing"], limit: 15)

      assert :ok = Jobs.show_list()

      opts = Storage.get_last_jobs_opts()

      assert ["executing"] == Keyword.get(opts, :states)
      assert 15 == Keyword.get(opts, :limit)
    end

    test "reuses the last listed ids when 0 is given as id" do
      Mimic.stub(Repo, :all, fn _ -> ObanConfigMock.jobs() end)

      Storage.set_last_jobs_ids([10, 20])

      assert :ok = Jobs.show_list(ids: [0])

      assert [10, 20] == Keyword.get(Storage.get_last_jobs_opts(), :ids)
    end

    test "cleans the stored options when the listing fails" do
      Mimic.stub(Repo, :all, fn _ -> raise "boom" end)

      Storage.set_last_jobs_opts(states: ["executing"])

      assert :ok = Jobs.show_list()

      assert [] == Storage.get_last_jobs_opts()
    end
  end

  describe "clean_storage/0" do
    test "removes the stored options" do
      Storage.set_last_jobs_opts(states: ["executing"])

      assert :ok = Jobs.clean_storage()

      assert [] == Storage.get_last_jobs_opts()
    end
  end

  describe "debug_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.debug_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :get_job, 2, fn id -> ObanConfigMock.jobs() |> Enum.at(id - 1) end)

      assert :ok = Jobs.debug_jobs([1, 2])
    end

    test "with a single id" do
      Mimic.expect(Repo, :get_job, fn _ -> List.first(ObanConfigMock.jobs()) end)

      assert :ok = Jobs.debug_jobs(1)
    end

    test "when the job is not found" do
      Mimic.expect(Repo, :get_job, fn _ -> nil end)

      assert :ok = Jobs.debug_jobs(999)
    end

    test "with an invalid id" do
      assert :ok = Jobs.debug_jobs("1")
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
      Mimic.expect(Repo, :retry_job, fn _ -> :ok end)

      assert :ok = Jobs.retry_jobs(1)
    end

    test "with an invalid id" do
      assert :ok = Jobs.retry_jobs("1")
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
      Mimic.expect(Repo, :cancel_job, fn _ -> :ok end)

      assert :ok = Jobs.cancel_jobs(1)
    end

    test "with an invalid id" do
      assert :ok = Jobs.cancel_jobs("1")
    end
  end
end
