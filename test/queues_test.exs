defmodule Oban.Console.QueuesTest do
  use ExUnit.Case
  use Mimic

  alias Oban.Console.Queues

  describe "list/0" do
    test "returns list of queues with their status" do
      config = %Oban.Config{queues: [default: 10, mailers: 5], repo: nil}

      expect(Oban, :config, fn -> config end)

      expect(Oban, :check_queue, fn [queue: :default] ->
        %{
          queue: :default,
          paused: false,
          local_limit: 10,
          global_limit: nil,
          rate_limit: nil
        }
      end)

      expect(Oban, :check_queue, fn [queue: :mailers] ->
        %{
          queue: :mailers,
          paused: true,
          local_limit: 5,
          global_limit: nil,
          rate_limit: nil
        }
      end)

      assert [
               %{queue: :default, paused: false, local_limit: 10},
               %{queue: :mailers, paused: true, local_limit: 5}
             ] = Queues.list()
    end
  end

  describe "pause_queues/1" do
    test "pauses a single queue by binary name" do
      expect(Oban, :pause_queue, fn [queue: "default"] -> :ok end)

      assert :ok = Queues.pause_queues("default")
    end

    test "pauses multiple queues by list of names" do
      expect(Oban, :pause_queue, fn [queue: "default"] -> :ok end)
      expect(Oban, :pause_queue, fn [queue: "mailers"] -> :ok end)

      assert :ok = Queues.pause_queues(["default", "mailers"])
    end

    test "returns :ok for empty list" do
      assert :ok = Queues.pause_queues([])
    end

    test "returns :error for invalid name" do
      assert :error = Queues.pause_queues(123)
      assert :error = Queues.pause_queues(nil)
    end
  end

  describe "resume_queues/1" do
    test "resumes a single queue by binary name" do
      expect(Oban, :resume_queue, fn [queue: "default"] -> :ok end)

      assert :ok = Queues.resume_queues("default")
    end

    test "resumes multiple queues by list of names" do
      expect(Oban, :resume_queue, fn [queue: "default"] -> :ok end)
      expect(Oban, :resume_queue, fn [queue: "mailers"] -> :ok end)

      assert :ok = Queues.resume_queues(["default", "mailers"])
    end

    test "returns :ok for empty list" do
      assert :ok = Queues.resume_queues([])
    end

    test "returns :error for invalid name" do
      assert :error = Queues.resume_queues(123)
      assert :error = Queues.resume_queues(nil)
    end
  end
end
