defmodule Oban.Console.JobsTest do
  use ExUnit.Case

  alias Oban.Console.Jobs
  alias Oban.Console.Repo
  alias Oban.Console.Storage

  setup do
    Mimic.stub(Storage, :set_last_jobs_ids, fn _ -> :ok end)
    Mimic.stub(Storage, :set_last_jobs_opts, fn _ -> :ok end)
    Mimic.stub(Storage, :add_job_filter_history, fn _ -> :ok end)
    Mimic.stub(Storage, :get_last_jobs_opts, fn -> [] end)
    Mimic.stub(Storage, :get_last_jobs_ids, fn -> [] end)

    :ok
  end

  describe "list/1" do
    test "returns the jobs from the repo" do
      Mimic.expect(Repo, :all, fn %Ecto.Query{} -> ObanConfigMock.jobs() end)

      assert ObanConfigMock.jobs() == Jobs.list()
    end

    test "accepts filters" do
      Mimic.expect(Repo, :all, fn %Ecto.Query{} -> [] end)

      assert [] ==
               Jobs.list(
                 ids: [1],
                 states: ["available"],
                 queues: ["default"],
                 workers: ["Search", "-Match"],
                 limit: 5
               )
    end
  end

  describe "show_list/1" do
    test "shows the list and stores ids and opts" do
      Mimic.stub(Repo, :all, fn _ -> ObanConfigMock.jobs() end)
      Mimic.expect(Storage, :set_last_jobs_ids, fn ids -> assert ids == [1, 2, 3] end)

      Mimic.expect(Storage, :set_last_jobs_opts, fn opts ->
        assert opts[:limit] == 20
        assert opts[:states] == ["available", "scheduled", "retryable", "executing"]
      end)

      assert :ok = Jobs.show_list(states: ["in_progress"])
    end

    test "uses the last stored opts when none are given" do
      Mimic.stub(Repo, :all, fn _ -> [] end)
      Mimic.expect(Storage, :get_last_jobs_opts, fn -> [limit: 5] end)
      Mimic.expect(Storage, :set_last_jobs_opts, fn opts -> assert opts[:limit] == 5 end)

      assert :ok = Jobs.show_list()
    end

    test "uses the last listed ids when ids is [0]" do
      Mimic.stub(Repo, :all, fn _ -> [] end)
      Mimic.expect(Storage, :get_last_jobs_ids, fn -> [7, 8] end)
      Mimic.expect(Storage, :set_last_jobs_opts, fn opts -> assert opts[:ids] == [7, 8] end)

      assert :ok = Jobs.show_list(ids: [0])
    end
  end

  describe "convert_states/1" do
    test "converts aliases and numeric shortcuts" do
      assert ["cancelled", "discarded"] == Jobs.convert_states(["failed"])
      assert ["available", "completed"] == Jobs.convert_states(["1", "5"])
      assert ["executing"] == Jobs.convert_states(["executing"])
      assert [] == Jobs.convert_states([])
    end
  end

  describe "clean_storage/0" do
    test "resets the stored opts" do
      Mimic.expect(Storage, :set_last_jobs_opts, fn [] -> :ok end)

      assert :ok = Jobs.clean_storage()
    end
  end

  describe "debug_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.debug_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :get_job, 2, fn id -> Factory.build(:job, id: id) end)

      assert :ok = Jobs.debug_jobs([1, 2])
    end

    test "with a job not found" do
      Mimic.expect(Repo, :get_job, fn _ -> nil end)

      assert :ok = Jobs.debug_jobs(1)
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
      Mimic.expect(Repo, :retry_job, fn 1 -> :ok end)

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
      Mimic.expect(Repo, :cancel_job, fn 1 -> :ok end)

      assert :ok = Jobs.cancel_jobs(1)
    end

    test "with an invalid id" do
      assert :ok = Jobs.cancel_jobs("1")
    end
  end
end
