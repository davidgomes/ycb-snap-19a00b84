defmodule GradingClientTest do
  use ExUnit.Case
  doctest GradingClient

  import ExUnit.CaptureIO

  describe "check_answer/3" do
    test "accepts the correct answer" do
      assert GradingClient.check_answer(:entry_granted_op2, "OWASP", 1) == :correct
    end

    test "returns the help text for an incorrect answer" do
      assert {:incorrect, help_text} = GradingClient.check_answer(:entry_granted_op1, "OWASP", 1)
      assert help_text =~ "Cryptographic Failures"
    end

    test "rejects answers to unknown questions" do
      assert GradingClient.check_answer(:plug, "OWASP", 0) == {:incorrect, "Question not found"}
    end
  end

  describe "grade/3" do
    test "prints feedback for a correct answer" do
      output = capture_io(fn -> assert GradingClient.grade(:plug, "OWASP", 2) == :correct end)

      assert output =~ "Correct!"
    end

    test "prints the help text for an incorrect answer" do
      output =
        capture_io(fn -> assert GradingClient.grade(:absinthe, "OWASP", 2) == :incorrect end)

      assert output =~ "Incorrect: "
      assert output =~ "version requirements in the setup cell"
    end
  end
end
