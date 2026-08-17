defmodule Oban.ConsoleTest do
  use ExUnit.Case
  use Mimic

  describe "list_queues/0" do
    test "delegates to Oban.Console.Queues.list/0" do
      config = %Oban.Config{queues: [default: 10], repo: nil}

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

      assert [%{queue: :default, paused: false, local_limit: 10}] = Oban.Console.list_queues()
    end
  end
end
