defmodule GradingClientTest do
  use ExUnit.Case

  test "OWASP password comparison quiz accepts bcrypt verification" do
    assert :correct = GradingClient.check_answer(OWASP, 1, :entry_granted_op2)
  end

  test "OWASP password comparison quiz rejects MD5 comparison" do
    assert {:incorrect, help_text} = GradingClient.check_answer(OWASP, 1, :entry_granted_op1)
    assert help_text =~ "MD5"
  end

  test "OWASP outdated components quiz accepts plug" do
    assert :correct = GradingClient.check_answer(OWASP, 2, :plug)
  end

  test "OWASP outdated components quiz rejects other options" do
    assert {:incorrect, help_text} = GradingClient.check_answer(OWASP, 2, :ecto)
    assert help_text =~ "changelog"
  end
end
