defmodule Oban.Console.JobsTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias Oban.Console.Jobs
  alias Oban.Console.Repo
  alias Oban.Console.Storage

  setup do
    System.put_env("OBAN_CONSOLE_PROFILE", "")
    System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", "")
    System.put_env("OBAN_CONSOLE_JOBS_LAST_IDS", "")

    Storage.delete_profile_file()

    :ok
  end

  defp capture_query(opts) do
    test_pid = self()

    Mimic.expect(Repo, :jobs, fn query ->
      send(test_pid, {:query, query})
      []
    end)

    Jobs.list(opts)

    assert_received {:query, query}

    query
  end

  defp where_params(%Ecto.Query{wheres: wheres}) do
    Enum.map(wheres, fn %{params: params} -> Enum.map(params, &elem(&1, 0)) end)
  end

  describe "list/1" do
    test "returns jobs from the repo" do
      Mimic.expect(Repo, :jobs, fn %Ecto.Query{} -> ObanConfigMock.jobs() end)

      assert ObanConfigMock.jobs() == Jobs.list()
    end

    test "without filters uses the default limit" do
      query = capture_query([])

      assert [] = query.wheres
      assert %{expr: 20} = query.limit
      assert length(query.order_bys) == 3
    end

    test "filters by ids" do
      query = capture_query(ids: [1, 2])

      assert [[[1, 2]]] = where_params(query)
    end

    test "filters by states" do
      query = capture_query(states: ["available", "scheduled"])

      assert [[["available", "scheduled"]]] = where_params(query)
    end

    test "filters by queues" do
      query = capture_query(queues: ["default"])

      assert [[["default"]]] = where_params(query)
    end

    test "filters by included and excluded workers" do
      query = capture_query(workers: ["Search", "-Match"])

      assert [["%Search%", false], ["%Match%", true]] = where_params(query)
    end

    test "ignores empty filters" do
      query = capture_query(ids: [], states: nil, queues: [], workers: nil)

      assert [] = query.wheres
    end

    test "applies the given limit" do
      query = capture_query(limit: 50)

      assert %{params: [{50, _}]} = query.limit
    end
  end

  describe "show_list/1" do
    test "shows the list and stores the listed ids and options" do
      Mimic.expect(Repo, :jobs, fn _ -> ObanConfigMock.jobs() end)

      output = capture_io(fn -> assert :ok = Jobs.show_list(queues: ["default"]) end)

      assert output =~ "Rows: 3"
      assert [1, 2, 3] = Storage.get_last_jobs_ids()

      assert [ids: [], limit: 20, queues: ["default"], states: []] =
               Enum.sort(Storage.get_last_jobs_opts())
    end

    test "shows an empty list" do
      Mimic.expect(Repo, :jobs, fn _ -> [] end)

      output = capture_io(fn -> assert :ok = Jobs.show_list() end)

      assert output =~ "No records found"
      assert [] = Storage.get_last_jobs_ids()
    end

    test "converts state shortcuts" do
      test_pid = self()

      Mimic.expect(Repo, :jobs, fn query ->
        send(test_pid, {:query, query})
        []
      end)

      capture_io(fn -> Jobs.show_list(states: ["1", "failed"]) end)

      assert_received {:query, query}
      assert [[["available", "cancelled", "discarded"]]] = where_params(query)
    end

    test "uses the last listed ids when ids is [0]" do
      Storage.set_last_jobs_ids([4, 5])
      test_pid = self()

      Mimic.expect(Repo, :jobs, fn query ->
        send(test_pid, {:query, query})
        []
      end)

      capture_io(fn -> Jobs.show_list(ids: [0]) end)

      assert_received {:query, query}
      assert [[[4, 5]]] = where_params(query)
    end

    test "uses the last options when none are given" do
      Storage.set_last_jobs_opts(queues: ["matching"], limit: 5)
      test_pid = self()

      Mimic.expect(Repo, :jobs, fn query ->
        send(test_pid, {:query, query})
        []
      end)

      capture_io(fn -> Jobs.show_list() end)

      assert_received {:query, query}
      assert [[["matching"]]] = where_params(query)
      assert %{params: [{5, _}]} = query.limit
    end

    test "adds the options to the selected profile history" do
      Storage.find_or_create_profile("search api", [])
      Mimic.expect(Repo, :jobs, fn _ -> [] end)

      capture_io(fn -> Jobs.show_list(queues: ["searching"]) end)

      assert {"search api", %{"filters" => [%{"queues" => ["searching"]}]}} =
               Storage.get_profile()
    end

    test "resets the last options and retries when listing fails" do
      Storage.set_last_jobs_opts(queues: ["broken"])

      Repo
      |> Mimic.expect(:jobs, fn _ -> raise "boom" end)
      |> Mimic.expect(:jobs, fn _ -> [] end)

      output = capture_io(fn -> assert :ok = Jobs.show_list() end)

      assert output =~ "boom"
      assert [ids: [], limit: 20, states: []] = Enum.sort(Storage.get_last_jobs_opts())
    end
  end

  describe "clean_storage/0" do
    test "clears the last options" do
      Storage.set_last_jobs_opts(queues: ["default"])

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

      output = capture_io(fn -> assert :ok = Jobs.debug_jobs([1, 2]) end)

      assert output =~ "Oban.Job"
    end

    test "with a single id" do
      [job | _] = ObanConfigMock.jobs()
      Mimic.expect(Repo, :get_job, fn 1 -> job end)

      output = capture_io(fn -> Jobs.debug_jobs(1) end)

      assert output =~ "MyApp.SearchWorker"
    end

    test "with a job not found" do
      Mimic.expect(Repo, :get_job, fn 99 -> nil end)

      assert capture_io(fn -> Jobs.debug_jobs(99) end) =~ "Job not found"
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :get_job, 1)

      assert capture_io(fn -> Jobs.debug_jobs("1") end) =~ "Job ID is not valid"
    end
  end

  describe "retry_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.retry_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :retry_job, 2, fn _ -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.retry_jobs([1, 2]) end)

      assert output =~ "Retried"
    end

    test "with a single id" do
      Mimic.expect(Repo, :retry_job, fn 1 -> :ok end)

      assert capture_io(fn -> Jobs.retry_jobs(1) end) =~ "Retried"
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :retry_job, 1)

      assert capture_io(fn -> Jobs.retry_jobs("1") end) =~ "Job ID is not valid"
    end
  end

  describe "cancel_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.cancel_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :cancel_job, 2, fn _ -> :ok end)

      output = capture_io(fn -> assert :ok = Jobs.cancel_jobs([1, 2]) end)

      assert output =~ "Cancelled"
    end

    test "with a single id" do
      Mimic.expect(Repo, :cancel_job, fn 1 -> :ok end)

      assert capture_io(fn -> Jobs.cancel_jobs(1) end) =~ "Cancelled"
    end

    test "with an invalid id" do
      Mimic.reject(Repo, :cancel_job, 1)

      assert capture_io(fn -> Jobs.cancel_jobs("1") end) =~ "Job ID is not valid"
    end
  end
end
