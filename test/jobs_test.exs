defmodule Oban.Console.JobsTest do
  use ExUnit.Case

  import Mimic

  alias Oban.Console.Jobs
  alias Oban.Console.Repo
  alias Oban.Console.Storage

  setup :verify_on_exit!

  setup do
    System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", "")
    System.put_env("OBAN_CONSOLE_JOBS_LAST_IDS", "")
    System.put_env("OBAN_CONSOLE_PROFILE", "")

    Storage.delete_profile_file()

    :ok
  end

  describe "list/1" do
    test "returns jobs" do
      Mimic.stub(Repo, :jobs, fn _ -> ObanConfigMock.jobs() end)

      assert ObanConfigMock.jobs() == Jobs.list()
    end

    test "uses the default limit without filters" do
      expect_jobs_query()

      assert [] = Jobs.list()

      assert_received {:jobs_query, query}
      assert [] = query.wheres
      assert 20 = limit_value(query)
    end

    test "filters by ids, states, queues and limit" do
      expect_jobs_query()

      assert [] =
               Jobs.list(
                 ids: [1, 2],
                 states: ["available", "executing"],
                 queues: ["default"],
                 limit: 5
               )

      assert_received {:jobs_query, query}
      assert inspect(query) =~ "j0.id in ^"
      assert inspect(query) =~ "j0.state in ^"
      assert inspect(query) =~ "j0.queue in ^"
      assert [[1, 2], ["available", "executing"], ["default"]] = where_params(query)
      assert 5 = limit_value(query)
    end

    test "filters by included and excluded workers" do
      expect_jobs_query()

      assert [] = Jobs.list(workers: ["Search", "-Match"])

      assert_received {:jobs_query, query}
      assert inspect(query) =~ "like(j0.worker, ^"
      assert inspect(query) =~ "not like(j0.worker, ^"
      assert "%Search%" in where_params(query)
      assert "%Match%" in where_params(query)
    end

    test "ignores empty filters" do
      expect_jobs_query()

      assert [] = Jobs.list(ids: [], states: nil, queues: [], workers: nil)

      assert_received {:jobs_query, query}
      assert [] = query.wheres
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
      assert [] = Storage.get_last_jobs_ids()
    end

    test "stores listed ids and options" do
      Mimic.stub(Repo, :jobs, fn _ -> ObanConfigMock.jobs() end)

      assert :ok = Jobs.show_list(queues: ["default"], limit: 5)

      assert [1, 2, 3] = Storage.get_last_jobs_ids()

      opts = Storage.get_last_jobs_opts()

      assert ["default"] = Keyword.get(opts, :queues)
      assert 5 = Keyword.get(opts, :limit)
      assert [] = Keyword.get(opts, :ids)
      assert [] = Keyword.get(opts, :states)
    end

    test "converts state aliases" do
      states = ~w[available scheduled retryable executing completed cancelled discarded]

      expect_jobs_query()

      assert :ok = Jobs.show_list(states: ["in_progress", "5", "failed"])

      assert_received {:jobs_query, query}
      assert [^states] = where_params(query)
      assert ^states = Keyword.get(Storage.get_last_jobs_opts(), :states)
    end

    test "uses the ids listed before when ids is [0]" do
      Storage.set_last_jobs_ids([4, 5])

      expect_jobs_query()

      assert :ok = Jobs.show_list(ids: [0])

      assert_received {:jobs_query, query}
      assert [[4, 5]] = where_params(query)
    end

    test "uses the last options when no options are given" do
      Storage.set_last_jobs_opts(queues: ["searching"], limit: 7)

      expect_jobs_query()

      assert :ok = Jobs.show_list()

      assert_received {:jobs_query, query}
      assert [["searching"]] = where_params(query)
      assert 7 = limit_value(query)
    end

    test "adds the options to the selected profile history" do
      Mimic.stub(Repo, :jobs, fn _ -> [] end)

      assert :ok = Storage.find_or_create_profile("search api", [])
      assert :ok = Jobs.show_list(queues: ["default"])

      assert {"search api", %{"filters" => [%{"queues" => ["default"]}]}} = Storage.get_profile()
    end

    test "cleans the last options and lists again on error" do
      Mimic.expect(Repo, :jobs, fn _ -> raise "query failed" end)
      expect_jobs_query(ObanConfigMock.jobs())

      assert :ok = Jobs.show_list(queues: ["default"])

      assert_received {:jobs_query, query}
      assert [] = query.wheres
      assert [1, 2, 3] = Storage.get_last_jobs_ids()
      refute Keyword.has_key?(Storage.get_last_jobs_opts(), :queues)
    end
  end

  describe "clean_storage/0" do
    test "cleans the last options" do
      Storage.set_last_jobs_opts(states: ["available"], limit: 50)

      Jobs.clean_storage()

      assert [] = Storage.get_last_jobs_opts()
    end
  end

  describe "debug_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.debug_jobs([])
    end

    test "with a list of ids" do
      [job | _] = ObanConfigMock.jobs()

      Mimic.expect(Repo, :get_job, 2, fn _ -> job end)

      assert :ok = Jobs.debug_jobs([1, 2])
    end

    test "with a single id" do
      [job | _] = ObanConfigMock.jobs()

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

  defp expect_jobs_query(jobs \\ []) do
    test_pid = self()

    Mimic.expect(Repo, :jobs, fn query ->
      send(test_pid, {:jobs_query, query})

      jobs
    end)
  end

  defp where_params(query) do
    Enum.flat_map(query.wheres, fn where -> Enum.map(where.params, &elem(&1, 0)) end)
  end

  defp limit_value(%Ecto.Query{limit: %{params: [{value, _}]}}), do: value
  defp limit_value(%Ecto.Query{limit: %{expr: value}}), do: value
end
