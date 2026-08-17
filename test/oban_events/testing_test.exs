defmodule ObanEvents.TestingTest do
  use ExUnit.Case, async: true

  defmodule SomeHandler do
    @moduledoc false
  end

  describe "build_enqueued_opts/3" do
    test "builds args from just an event name" do
      opts = ObanEvents.Testing.build_enqueued_opts([], :user_created, %{})

      assert opts[:worker] == ObanEvents.DispatchWorker
      assert opts[:args] == %{"event" => "user_created", "data" => %{}}
    end

    test "includes the given data in the args" do
      opts =
        ObanEvents.Testing.build_enqueued_opts([], :user_created, %{"user_id" => 123})

      assert opts[:args] == %{"event" => "user_created", "data" => %{"user_id" => 123}}
    end

    test "adds the handler to args and removes it from the returned opts" do
      opts =
        ObanEvents.Testing.build_enqueued_opts([handler: SomeHandler], :user_created, %{})

      assert opts[:args] == %{
               "event" => "user_created",
               "data" => %{},
               "handler" => "Elixir.ObanEvents.TestingTest.SomeHandler"
             }

      refute Keyword.has_key?(opts, :handler)
    end

    test "passes through other options untouched" do
      opts =
        ObanEvents.Testing.build_enqueued_opts([queue: :custom_queue], :user_created, %{})

      assert opts[:queue] == :custom_queue
      assert opts[:worker] == ObanEvents.DispatchWorker
    end
  end

  describe "__using__/1" do
    defmodule UserOfTesting do
      @moduledoc false
      use ObanEvents.Testing, repo: ObanEvents.Test.Repo
    end

    test "defines assert_event_emitted/1,2,3 and refute_event_emitted/1,2,3" do
      assert function_exported?(UserOfTesting, :assert_event_emitted, 1)
      assert function_exported?(UserOfTesting, :assert_event_emitted, 2)
      assert function_exported?(UserOfTesting, :assert_event_emitted, 3)
      assert function_exported?(UserOfTesting, :refute_event_emitted, 1)
      assert function_exported?(UserOfTesting, :refute_event_emitted, 2)
      assert function_exported?(UserOfTesting, :refute_event_emitted, 3)
    end

    test "also configures Oban.Testing's assert_enqueued/refute_enqueued" do
      assert function_exported?(UserOfTesting, :assert_enqueued, 1)
      assert function_exported?(UserOfTesting, :refute_enqueued, 1)
    end
  end
end
