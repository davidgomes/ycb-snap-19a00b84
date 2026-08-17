defmodule GradingClientTest do
  use ExUnit.Case

  test "OWASP question 1 accepts bcrypt password comparison result" do
    assert :correct = GradingClient.check_answer(OWASP, 1, :entry_granted_op2)
  end

  test "OWASP question 1 rejects MD5 password comparison result" do
    assert {:incorrect, help_text} = GradingClient.check_answer(OWASP, 1, :entry_granted_op1)
    assert help_text == "Research MD5 Rainbow Tables"
  end

  test "OWASP question 2 accepts the vulnerable plug package" do
    assert :correct = GradingClient.check_answer(OWASP, 2, :plug)
  end

  test "OWASP question 2 rejects other listed packages" do
    assert {:incorrect, help_text} = GradingClient.check_answer(OWASP, 2, :ecto)
    assert help_text =~ "changelog"
  end

  test "get_modules includes OWASP" do
    assert OWASP in GradingClient.Answers.get_modules()
  end
end
