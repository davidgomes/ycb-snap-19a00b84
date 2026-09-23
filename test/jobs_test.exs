defmodule Oban.Console.JobsTest do
  use ExUnit.Case

  alias Oban.Console.Jobs
  alias Oban.Console.Repo
  alias Oban.Console.Storage

  setup do
    System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", "")
    System.put_env("OBAN_CONSOLE_JOBS_LAST_IDS", "")
    :ok
  end

  describe "list/1" do
    test "returns jobs" do
      Mimic.stub(Repo, :jobs, fn _ -> ObanConfigMock.jobs() end)

      assert ObanConfigMock.jobs() == Jobs.list()
    end

    test "passes options to the repo" do
      opts = [states: ["scheduled"], limit: 50]

      Mimic.expect(Repo, :jobs, fn ^opts -> [] end)

      assert [] = Jobs.list(opts)
    end

    test "stores last options and ids" do
      opts = [states: ["scheduled"], limit: 50]

      Mimic.stub(Repo, :jobs, fn _ -> ObanConfigMock.jobs() end)

      Jobs.list(opts)

      assert ^opts = Storage.get_last_jobs_opts()
      assert [1, 2, 3] = Storage.get_last_jobs_ids()
    end
  end

  describe "show_list/1" do
    test "shows the list" do
      Mimic.stub(Repo, :jobs, fn _ -> ObanConfigMock.jobs() end)

      assert :ok = Jobs.show_list()
    end

    test "shows an empty list" do
      Mimic.stub(Repo, :jobs, fn _ -> [] end)

      assert :ok = Jobs.show_list()
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
      assert :ok = Jobs.cancel_jobs("abc")
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
      assert :ok = Jobs.retry_jobs("abc")
    end
  end
end
