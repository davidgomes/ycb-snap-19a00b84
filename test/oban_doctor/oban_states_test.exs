defmodule ObanDoctor.ObanStatesTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.ObanStates

  describe "named_groups/0" do
    test "returns the four named groups" do
      assert Enum.sort(ObanStates.named_groups()) ==
               Enum.sort([:all, :incomplete, :scheduled, :successful])
    end
  end

  describe "named_group?/1" do
    test "returns true for each named group atom" do
      assert ObanStates.named_group?(:all)
      assert ObanStates.named_group?(:incomplete)
      assert ObanStates.named_group?(:scheduled)
      assert ObanStates.named_group?(:successful)
    end

    test "returns true for a list containing :all" do
      assert ObanStates.named_group?([:all])
      assert ObanStates.named_group?([:available, :all])
    end

    test "returns false for explicit state lists without :all" do
      refute ObanStates.named_group?([:available, :scheduled, :executing, :retryable])
    end

    test "returns false for nil and other values" do
      refute ObanStates.named_group?(nil)
      refute ObanStates.named_group?(:unknown_group)
    end
  end

  describe "expand/1" do
    test "expands :all to every job state" do
      assert ObanStates.expand(:all) == [
               :scheduled,
               :available,
               :executing,
               :retryable,
               :completed,
               :discarded,
               :cancelled
             ]
    end

    test "expands :incomplete to non-final states" do
      assert ObanStates.expand(:incomplete) == [:available, :scheduled, :executing, :retryable]
    end

    test "expands :scheduled to only the scheduled state" do
      assert ObanStates.expand(:scheduled) == [:scheduled]
    end

    test "expands :successful to states excluding cancelled/discarded" do
      assert ObanStates.expand(:successful) == [
               :available,
               :scheduled,
               :executing,
               :retryable,
               :completed
             ]
    end

    test "returns nil for a non-named-group value" do
      assert ObanStates.expand([:available]) == nil
      assert ObanStates.expand(:unknown_group) == nil
    end
  end
end
