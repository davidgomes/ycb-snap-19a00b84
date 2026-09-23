defmodule GradingClientTest do
  use ExUnit.Case
  doctest GradingClient

  describe "check_answer/3" do
    test "returns an error for an unknown question" do
      assert GradingClient.check_answer(:anything, OWASP, 0) == {:incorrect, "Question not found"}
    end

    test "OWASP question 1 expects the bcrypt comparison" do
      assert GradingClient.check_answer(:entry_granted_op2, OWASP, 1) == :correct
      assert {:incorrect, help_text} = GradingClient.check_answer(:entry_granted_op1, OWASP, 1)
      assert help_text =~ "MD5"
    end

    test "OWASP question 2 expects plug to be identified and updated" do
      assert GradingClient.check_answer({:plug, ~c"1.20.3"}, OWASP, 2) == :correct
      assert GradingClient.check_answer({:plug, ~c"1.4.0"}, OWASP, 2) == :correct

      assert {:incorrect, _} = GradingClient.check_answer({:plug, ~c"1.3.6"}, OWASP, 2)
      assert {:incorrect, _} = GradingClient.check_answer({:plug, nil}, OWASP, 2)
      assert {:incorrect, _} = GradingClient.check_answer({:absinthe, ~c"1.7.8"}, OWASP, 2)
      assert {:incorrect, _} = GradingClient.check_answer({:vulnerable_dependency, nil}, OWASP, 2)
    end
  end
end
