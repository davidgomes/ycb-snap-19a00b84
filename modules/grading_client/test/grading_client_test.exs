defmodule GradingClientTest do
  use ExUnit.Case
  doctest GradingClient

  describe "OWASP module" do
    test "password comparison question" do
      assert GradingClient.check_answer(:entry_granted_op2, OWASP, 1) == :correct
      assert {:incorrect, help_text} = GradingClient.check_answer(:entry_granted_op1, OWASP, 1)
      assert is_binary(help_text)
    end

    test "vulnerable dependency question" do
      assert GradingClient.check_answer(:plug, OWASP, 2) == :correct
      assert {:incorrect, _} = GradingClient.check_answer(:vulnerable_dependency, OWASP, 2)
    end
  end

  test "unknown question" do
    assert GradingClient.check_answer(:anything, OWASP, 999) ==
             {:incorrect, "Question not found"}
  end
end
