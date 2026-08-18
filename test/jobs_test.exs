defmodule Oban.Console.JobsTest do
  use ExUnit.Case

  alias Oban.Console.Jobs
  alias Oban.Console.Repo
  alias Oban.Console.Storage

  describe "list/1" do
    test "returns jobs" do
      Mimic.stub(Repo, :all, fn _query -> ObanMock.jobs() end)

      assert ObanMock.jobs() == Jobs.list()
    end
  end

  describe "show_list/1" do
    setup do
      System.delete_env("OBAN_CONSOLE_JOBS_LAST_OPTS")
      System.delete_env("OBAN_CONSOLE_JOBS_LAST_IDS")
      Storage.delete_profile_file()

      on_exit(fn ->
        System.delete_env("OBAN_CONSOLE_JOBS_LAST_OPTS")
        System.delete_env("OBAN_CONSOLE_JOBS_LAST_IDS")
        Storage.delete_profile_file()
      end)
    end

    test "shows the list and remembers job ids and options" do
      Mimic.stub(Repo, :all, fn _query -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list()
      assert Enum.map(ObanMock.jobs(), & &1.id) == Storage.get_last_jobs_ids()
      assert [ids: [], states: [], limit: 20] == Storage.get_last_jobs_opts()
    end

    test "adds selected options to the active profile" do
      Mimic.stub(Repo, :all, fn _query -> ObanMock.jobs() end)
      assert :ok = Storage.find_or_create_profile("API", [])

      assert :ok = Jobs.show_list(limit: 50, states: ["scheduled"])

      assert {"API",
              %{
                "filters" => [
                  %{"ids" => [], "limit" => 50, "states" => ["scheduled"]}
                ]
              }} = Storage.get_profile()
    end

    test "converts state shortcuts before querying" do
      Mimic.expect(Repo, :all, fn query ->
        query = inspect(query)
        assert query =~ "available"
        assert query =~ "executing"
        assert query =~ "cancelled"
        assert query =~ "discarded"
        []
      end)

      assert :ok = Jobs.show_list(states: ["in_progress", "failed"])
    end
  end

  describe "clean_storage/0" do
    test "clears the remembered options" do
      Storage.set_last_jobs_opts(limit: 50)

      assert :ok = Jobs.clean_storage()
      assert [] == Storage.get_last_jobs_opts()
    end
  end
end
