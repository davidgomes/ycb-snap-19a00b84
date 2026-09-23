defmodule GradingClientTest do
  use ExUnit.Case
  doctest GradingClient

  describe "check_answer/3" do
    test "returns :correct for the right answer" do
      assert GradingClient.check_answer(:entry_granted_op2, 2, 1) == :correct
      assert GradingClient.check_answer(:plug, 2, 2) == :correct
    end

    test "returns the help text for a wrong answer" do
      assert {:incorrect, help_text} = GradingClient.check_answer(:entry_granted_op1, 2, 1)
      assert help_text =~ "MD5"
    end

    test "reports questions that do not exist" do
      assert GradingClient.check_answer(:plug, 2, 999) == {:incorrect, "Question not found"}
    end
  end
end
