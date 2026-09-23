defmodule GradingClientTest do
  use ExUnit.Case
  doctest GradingClient

  import ExUnit.CaptureIO

  describe "OWASP answers" do
    test "question 1 expects the bcrypt comparison" do
      assert GradingClient.check_answer(:entry_granted_op2, OWASP, 1) == :correct
      assert {:incorrect, _} = GradingClient.check_answer(:entry_granted_op1, OWASP, 1)
    end

    test "question 2 expects the vulnerable plug dependency" do
      assert GradingClient.check_answer(:plug, OWASP, 2) == :correct
      assert {:incorrect, _} = GradingClient.check_answer(:vulnerable_dependency, OWASP, 2)
    end
  end

  describe "self_evaluate/3" do
    test "prints feedback for correct answers" do
      output = capture_io(fn -> GradingClient.self_evaluate(:plug, OWASP, 2) end)

      assert output =~ "Correct!"
    end

    test "prints help text for incorrect answers" do
      output = capture_io(fn -> GradingClient.self_evaluate(:phoenix, OWASP, 2) end)

      assert output =~ "Incorrect: "
      assert output =~ "setup cell"
    end

    test "handles unknown questions" do
      output = capture_io(fn -> GradingClient.self_evaluate(:anything, OWASP, 999) end)

      assert output =~ "Incorrect: "
      assert output =~ "Question not found"
    end
  end

  describe "GradedCell.to_source/1" do
    test "evaluates the user source and grades the result" do
      source =
        GradingClient.GradedCell.to_source(%{
          "module_id" => "OWASP",
          "question_id" => 2,
          "source" => "vulnerable_dependency = :plug\nvulnerable_dependency"
        })

      output = capture_io(fn -> assert {:correct, _} = Code.eval_string(source) end)

      assert output =~ "Correct!"
    end

    test "returns the raw source when it cannot be parsed" do
      attrs = %{"module_id" => "OWASP", "question_id" => 1, "source" => "defmodule do"}

      assert GradingClient.GradedCell.to_source(attrs) == "defmodule do"
    end
  end
end
