defmodule ObanDoctorTest do
  use ExUnit.Case, async: true

  describe "discover_workers/1" do
    test "returns empty list for directory with no workers" do
      # Uses the test fixtures directory
      workers = ObanDoctor.discover_workers(Path.join(__DIR__, "fixtures/empty_project"))
      assert workers == []
    end
  end

  describe "discover_queues/1" do
    test "returns empty set for directory with no config" do
      queues = ObanDoctor.discover_queues(Path.join(__DIR__, "fixtures/empty_project"))
      assert MapSet.size(queues) == 0
    end
  end
end
