defmodule GradingClientTest do
  use ExUnit.Case

  describe "OWASP self-evaluation" do
    test "question 1 accepts bcrypt password comparison" do
      assert :correct = GradingClient.check_answer(OWASP, 1, :entry_granted_op2)
    end

    test "question 1 rejects MD5 password comparison with help text" do
      assert {:incorrect, help_text} = GradingClient.check_answer(OWASP, 1, :entry_granted_op1)
      assert help_text =~ "MD5"
    end

    test "question 2 accepts the vulnerable Plug dependency" do
      assert :correct = GradingClient.check_answer(OWASP, 2, :plug)
    end

    test "question 2 rejects other packages with changelog guidance" do
      assert {:incorrect, help_text} = GradingClient.check_answer(OWASP, 2, :ecto)
      assert help_text =~ "changelog"
    end
  end

  test "get_modules includes OWASP" do
    assert OWASP in GradingClient.Answers.get_modules()
  end

  test "unknown questions return a not-found result" do
    assert {:incorrect, "Question not found"} = GradingClient.check_answer(OWASP, 99, :anything)
  end
end
