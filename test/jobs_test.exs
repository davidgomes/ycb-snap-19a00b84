defmodule Oban.Console.JobsTest do
  use ExUnit.Case
  use Mimic

  import ExUnit.CaptureIO

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
    test "returns jobs from the repo" do
      stub(Repo, :jobs, fn _query -> ObanConfigMock.jobs() end)

      assert ObanConfigMock.jobs() == Jobs.list()
    end

    test "without filters limits to 20 jobs" do
      expect_jobs_query([])

      Jobs.list()

      assert_received {:query, query}
      assert [] == query.wheres
      assert 20 == limit_value(query)
    end

    test "sorts by attempted_at and scheduled_at" do
      expect_jobs_query([])

      Jobs.list()

      assert_received {:query, query}
      assert inspect(query) =~ "desc: j0.attempted_at"
      assert inspect(query) =~ "desc: j0.scheduled_at"
    end

    test "filters by ids, states, queues and limit" do
      expect_jobs_query([])

      Jobs.list(ids: [1, 2], states: ["completed"], queues: ["default"], limit: 5)

      assert_received {:query, query}
      assert [[1, 2], ["completed"], ["default"]] == where_params(query)
      assert 5 == limit_value(query)
    end

    test "ignores empty and nil filters" do
      expect_jobs_query([])

      Jobs.list(ids: [], states: nil, queues: [], workers: nil)

      assert_received {:query, query}
      assert [] == query.wheres
    end

    test "filters workers including and excluding by pattern" do
      expect_jobs_query([])

      Jobs.list(workers: ["Search", "Match", "-Default"])

      assert_received {:query, query}
      assert [include, exclude] = query.wheres

      assert ["%Search%", "%Match%"] == include |> params_of() |> Enum.filter(&is_binary/1)
      assert ["%Default%"] == exclude |> params_of() |> Enum.filter(&is_binary/1)
      assert inspect(query) =~ ~s[not like(j0.worker, ^"%Default%")]
    end
  end

  describe "show_list/1" do
    test "shows the jobs and stores listed ids and options" do
      stub(Repo, :jobs, fn _query -> ObanConfigMock.jobs() end)

      output = capture_io(fn -> assert :ok = Jobs.show_list(queues: ["default"]) end)

      assert output =~ "Rows: 3"
      assert output =~ "MyApp.Workers.SearchWorker"
      assert [1, 2, 3] == Storage.get_last_jobs_ids()

      assert [ids: [], limit: 20, queues: ["default"], states: []] ==
               Enum.sort(Storage.get_last_jobs_opts())
    end

    test "shows a message without jobs" do
      stub(Repo, :jobs, fn _query -> [] end)

      output = capture_io(fn -> assert :ok = Jobs.show_list() end)

      assert output =~ "Rows: 0"
      assert output =~ "No records found"
      assert [] == Storage.get_last_jobs_ids()
    end

    test "uses the last options when none are given" do
      Storage.set_last_jobs_opts(queues: ["matching"], limit: 5)
      expect_jobs_query([])

      capture_io(fn -> Jobs.show_list() end)

      assert_received {:query, query}
      assert [["matching"]] == where_params(query)
      assert 5 == limit_value(query)
    end

    test "converts state numbers and groups" do
      expect_jobs_query([])

      capture_io(fn -> Jobs.show_list(states: ["2", "in_progress", "failed", "completed"]) end)

      assert_received {:query, query}

      assert [
               [
                 "scheduled",
                 "available",
                 "scheduled",
                 "retryable",
                 "executing",
                 "cancelled",
                 "discarded",
                 "completed"
               ]
             ] == where_params(query)
    end

    test "filters by the last listed ids when ids is [0]" do
      Storage.set_last_jobs_ids([4, 5])
      expect_jobs_query([])

      capture_io(fn -> Jobs.show_list(ids: [0]) end)

      assert_received {:query, query}
      assert [[4, 5]] == where_params(query)
    end

    test "uses defaults for nil options" do
      expect_jobs_query([])

      capture_io(fn -> Jobs.show_list(ids: nil, states: nil, limit: nil) end)

      assert_received {:query, query}
      assert [] == query.wheres
      assert 20 == limit_value(query)
    end

    test "adds the options to the selected profile history" do
      stub(Repo, :jobs, fn _query -> [] end)
      Storage.find_or_create_profile("search api", [])

      capture_io(fn -> Jobs.show_list(limit: 5) end)

      assert {"search api", %{"filters" => [%{"limit" => 5, "ids" => [], "states" => []}]}} =
               Storage.get_profile()
    end

    test "resets the stored options and lists again on error" do
      Storage.set_last_jobs_opts(queues: ["matching"])

      Repo
      |> expect(:jobs, fn _query -> raise "database error" end)
      |> expect(:jobs, fn query ->
        send(self(), {:query, query})
        []
      end)

      output = capture_io(fn -> assert :ok = Jobs.show_list() end)

      assert output =~ "database error"
      assert output =~ "No records found"

      assert_received {:query, query}
      assert [] == query.wheres
    end
  end

  describe "clean_storage/0" do
    test "resets the stored options" do
      Storage.set_last_jobs_opts(queues: ["matching"], limit: 5)

      Jobs.clean_storage()

      assert [] == Storage.get_last_jobs_opts()
    end
  end

  describe "debug_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.debug_jobs([])
    end

    test "with a list of ids" do
      expect(Repo, :get_job, 2, fn id -> Factory.build(:job, id: id) end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs([1, 2]) end)

      assert output =~ "Job\e[0m | 1"
      assert output =~ "Job\e[0m | 2"
    end

    test "with an existing job id" do
      job = Factory.build(:job, id: 1)
      expect(Repo, :get_job, fn 1 -> job end)

      output = capture_io(fn -> assert ^job = Jobs.debug_jobs(1) end)

      assert output =~ "%Oban.Job{"
    end

    test "with a missing job id" do
      expect(Repo, :get_job, fn 1 -> nil end)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs(1) end)

      assert output =~ "Job not found"
    end

    test "with an invalid job id" do
      reject(Repo, :get_job, 1)

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs("1") end)

      assert output =~ "Job ID is not valid"
    end
  end

  describe "retry_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.retry_jobs([])
    end

    test "with a list of ids" do
      expect(Repo, :retry_job, 2, fn _ -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.retry_jobs([1, 2]) end)

      assert output =~ "Retried\e[0m | 1"
      assert output =~ "Retried\e[0m | 2"
    end

    test "with a single id" do
      expect(Repo, :retry_job, fn 1 -> :ok end)

      capture_io(fn -> assert :ok = Jobs.retry_jobs(1) end)
    end

    test "with an invalid id" do
      reject(Repo, :retry_job, 1)

      output = capture_io(fn -> assert :ok = Jobs.retry_jobs("1") end)

      assert output =~ "Job ID is not valid"
    end
  end

  describe "cancel_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.cancel_jobs([])
    end

    test "with a list of ids" do
      expect(Repo, :cancel_job, 2, fn _ -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs([1, 2]) end)

      assert output =~ "Cancelled\e[0m | 1"
      assert output =~ "Cancelled\e[0m | 2"
    end

    test "with a single id" do
      expect(Repo, :cancel_job, fn 1 -> :ok end)

      capture_io(fn -> assert :ok = Jobs.cancel_jobs(1) end)
    end

    test "with an invalid id" do
      reject(Repo, :cancel_job, 1)

      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs("1") end)

      assert output =~ "Job ID is not valid"
    end
  end

  defp expect_jobs_query(response) do
    expect(Repo, :jobs, fn query ->
      send(self(), {:query, query})
      response
    end)
  end

  defp where_params(query), do: Enum.flat_map(query.wheres, &params_of/1)

  defp params_of(%{params: params}), do: Enum.map(params, &elem(&1, 0))

  defp limit_value(%{limit: %{params: [{value, _}]}}), do: value
  defp limit_value(%{limit: %{expr: value}}), do: value
end
