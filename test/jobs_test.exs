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

  defp where_params(%Ecto.Query{wheres: wheres}) do
    Enum.flat_map(wheres, fn %{params: params} -> Enum.map(params, &elem(&1, 0)) end)
  end

  defp limit_value(%Ecto.Query{limit: %{params: [{limit, _}]}}), do: limit
  defp limit_value(%Ecto.Query{limit: %{expr: limit}}), do: limit

  describe "list/1" do
    test "returns jobs" do
      Mimic.expect(Repo, :jobs, fn _query -> ObanConfigMock.jobs() end)

      assert ObanConfigMock.jobs() == Jobs.list()
    end

    test "builds query with default limit and without filters" do
      Mimic.expect(Repo, :jobs, fn query ->
        assert [] = query.wheres
        assert 20 = limit_value(query)
        assert 3 = length(query.order_bys)

        []
      end)

      assert [] = Jobs.list()
    end

    test "builds query filtering by ids, states and queues" do
      Mimic.expect(Repo, :jobs, fn query ->
        assert [[1, 2], ["available"], ["default"]] = where_params(query)
        assert 50 = limit_value(query)

        []
      end)

      assert [] = Jobs.list(ids: [1, 2], states: ["available"], queues: ["default"], limit: 50)
    end

    test "builds query including and excluding workers" do
      Mimic.expect(Repo, :jobs, fn query ->
        assert ["%Search%", "%Matching%"] = query |> where_params() |> Enum.filter(&is_binary/1)

        []
      end)

      assert [] = Jobs.list(workers: ["Search", "-Matching"])
    end

    test "ignores empty filters" do
      Mimic.expect(Repo, :jobs, fn query ->
        assert [] = query.wheres

        []
      end)

      assert [] = Jobs.list(ids: [], states: nil, queues: [], workers: nil)
    end
  end

  describe "show_list/1" do
    test "shows the list and stores listed ids and options" do
      Mimic.expect(Repo, :jobs, fn _query -> ObanConfigMock.jobs() end)

      assert :ok = Jobs.show_list(states: ["available"], limit: 10)

      assert [1, 2, 3] = Storage.get_last_jobs_ids()

      opts = Storage.get_last_jobs_opts()
      assert ["available"] = Keyword.get(opts, :states)
      assert 10 = Keyword.get(opts, :limit)
    end

    test "shows empty list" do
      Mimic.expect(Repo, :jobs, fn _query -> [] end)

      assert :ok = Jobs.show_list(limit: 10)
      assert [] = Storage.get_last_jobs_ids()
    end

    test "converts state numbers and groups" do
      states = ~w[scheduled available scheduled retryable executing cancelled discarded]

      Mimic.expect(Repo, :jobs, fn query ->
        assert [^states] = where_params(query)

        []
      end)

      assert :ok = Jobs.show_list(states: ["2", "in_progress", "failed"])
    end

    test "uses default limit when limit is nil" do
      Mimic.expect(Repo, :jobs, fn query ->
        assert 20 = limit_value(query)

        []
      end)

      assert :ok = Jobs.show_list(limit: nil, states: nil)
    end

    test "uses last listed ids when ids is [0]" do
      Storage.set_last_jobs_ids([4, 5])

      Mimic.expect(Repo, :jobs, fn query ->
        assert [[4, 5]] = where_params(query)

        []
      end)

      assert :ok = Jobs.show_list(ids: [0])
    end

    test "uses last options when options are empty" do
      Storage.set_last_jobs_opts(queues: ["searching"], limit: 5)

      Mimic.expect(Repo, :jobs, fn query ->
        assert [["searching"]] = where_params(query)
        assert 5 = limit_value(query)

        []
      end)

      assert :ok = Jobs.show_list()
    end

    test "adds filters to the selected profile history" do
      Storage.find_or_create_profile("search api", [])

      Mimic.expect(Repo, :jobs, fn _query -> [] end)

      assert :ok = Jobs.show_list(limit: 10)

      assert {"search api", %{"filters" => [%{"limit" => 10}]}} = Storage.get_profile()
    end

    test "cleans last options and lists again on error" do
      Storage.set_last_jobs_opts(queues: ["searching"])

      Mimic.expect(Repo, :jobs, fn _query -> raise "query failed" end)

      Mimic.expect(Repo, :jobs, fn query ->
        assert [] = query.wheres

        []
      end)

      assert :ok = Jobs.show_list(queues: ["default"])
    end
  end

  describe "clean_storage/0" do
    test "cleans last options" do
      Storage.set_last_jobs_opts(limit: 10)

      Jobs.clean_storage()

      assert [] = Storage.get_last_jobs_opts()
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

    test "with a single id" do
      job = Factory.build(:job, id: 1)

      Mimic.expect(Repo, :get_job, fn 1 -> job end)

      assert ^job = Jobs.debug_jobs(1)
    end

    test "with a job not found" do
      Mimic.expect(Repo, :get_job, fn 1 -> nil end)

      assert :ok = Jobs.debug_jobs(1)
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :get_job, 1)

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
      Mimic.reject(Repo, :retry_job, 1)

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
      Mimic.reject(Repo, :cancel_job, 1)

      assert :ok = Jobs.cancel_jobs("1")
    end
  end
end
