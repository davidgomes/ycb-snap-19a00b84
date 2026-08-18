defmodule Oban.ConsoleTest do
  use ExUnit.Case

  alias Oban.Console
  alias Oban.Console.Repo

  describe "list_queues/0" do
    test "returns queues list" do
      Mimic.stub(Repo, :queues, fn -> ObanConfigMock.queues() end)

      assert ObanConfigMock.queues() == Console.list_queues()
    end
  end

  describe "list_jobs/1" do
    test "returns jobs list" do
      jobs = ObanConfigMock.jobs()
      Mimic.stub(Repo, :all_jobs, fn _opts -> jobs end)

      assert ^jobs = Console.list_jobs()
    end
  end
end
