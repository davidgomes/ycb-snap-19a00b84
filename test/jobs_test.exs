defmodule Oban.Console.JobsTest do
  use ExUnit.Case

  alias Oban.Console.Jobs
  alias Oban.Console.Repo
  alias Oban.Console.Storage

  describe "list/1" do
    test "returns jobs list" do
      Mimic.stub(Repo, :jobs, fn _opts -> ObanConfigMock.jobs() end)

      assert ObanConfigMock.jobs() == Jobs.list()
    end

    test "passes converted options to repo" do
      Mimic.expect(Repo, :jobs, fn opts ->
        assert Keyword.get(opts, :limit) == 10
        assert Keyword.get(opts, :states) == ["available", "scheduled", "retryable", "executing"]
        assert Keyword.get(opts, :ids) == [1, 2]
        ObanConfigMock.jobs()
      end)

      assert ObanConfigMock.jobs() ==
               Jobs.list(limit: 10, states: ["in_progress"], ids: [1, 2])
    end

    test "converts failed states and number state strings" do
      Mimic.expect(Repo, :jobs, fn opts ->
        assert Keyword.get(opts, :states) == ["cancelled", "discarded", "available", "completed"]
        ObanConfigMock.jobs()
      end)

      assert ObanConfigMock.jobs() ==
               Jobs.list(states: ["failed", "1", "5"])
    end

    test "handles [0] in ids by fetching last jobs ids from storage" do
      Storage.set_last_jobs_ids([10, 20])

      Mimic.expect(Repo, :jobs, fn opts ->
        assert Keyword.get(opts, :ids) == [10, 20]
        ObanConfigMock.jobs()
      end)

      assert ObanConfigMock.jobs() == Jobs.list(ids: [0])
    end
  end

  describe "show_list/1" do
    setup do
      System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", "")
      System.put_env("OBAN_CONSOLE_JOBS_LAST_IDS", "")
      :ok
    end

    test "shows the list and stores last ids and opts" do
      Mimic.stub(Repo, :jobs, fn _opts -> ObanConfigMock.jobs() end)

      assert :ok = Jobs.show_list()
      assert [1, 2, 3] == Storage.get_last_jobs_ids()
    end
  end

  describe "clean_storage/0" do
    test "cleans last jobs opts storage" do
      Storage.set_last_jobs_opts(limit: 50)
      assert [limit: 50] == Storage.get_last_jobs_opts()

      assert :ok = Jobs.clean_storage()
      assert [] == Storage.get_last_jobs_opts()
    end
  end

  describe "debug_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.debug_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :get_job, 2, fn
        1 -> Enum.at(ObanConfigMock.jobs(), 0)
        2 -> Enum.at(ObanConfigMock.jobs(), 1)
      end)

      assert :ok = Jobs.debug_jobs([1, 2])
    end

    test "with a single existing id" do
      Mimic.expect(Repo, :get_job, 1, fn 1 -> Enum.at(ObanConfigMock.jobs(), 0) end)

      assert :ok = Jobs.debug_jobs(1)
    end

    test "with a single non-existing id" do
      Mimic.expect(Repo, :get_job, 1, fn 999 -> nil end)

      assert :ok = Jobs.debug_jobs(999)
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
      Mimic.expect(Repo, :retry_job, 2, fn _ -> {:ok, %{}} end)

      assert :ok = Jobs.retry_jobs([1, 2])
    end

    test "with a single id" do
      Mimic.expect(Repo, :retry_job, 1, fn _ -> {:ok, %{}} end)

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
      Mimic.expect(Repo, :cancel_job, 2, fn _ -> {:ok, %{}} end)

      assert :ok = Jobs.cancel_jobs([1, 2])
    end

    test "with a single id" do
      Mimic.expect(Repo, :cancel_job, 1, fn _ -> {:ok, %{}} end)

      assert :ok = Jobs.cancel_jobs(1)
    end

    test "with an invalid id" do
      assert :ok = Jobs.cancel_jobs("invalid")
    end
  end
end
