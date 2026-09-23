defmodule GradingClient.GradedCellTest do
  use ExUnit.Case, async: true

  alias GradingClient.GradedCell

  defp attrs(question_id, source) do
    %{"module_id" => 2, "question_id" => question_id, "source" => source}
  end

  describe "to_source/1" do
    test "checks the result of the learner's code, keeping their comments" do
      source = "# CHANGE ME\nvulnerable_dependency = :plug\n\nvulnerable_dependency"

      assert GradedCell.to_source(attrs(2, source)) == """
             result =
               (
                 # CHANGE ME
                 vulnerable_dependency = :plug

                 vulnerable_dependency
               )

             GradingClient.check_answer(result, 2, 2)\
             """
    end

    test "generates code that evaluates to the grading result" do
      assert {:correct, _binding} = Code.eval_string(GradedCell.to_source(attrs(2, ":plug")))

      assert {{:incorrect, help_text}, _binding} =
               Code.eval_string(GradedCell.to_source(attrs(2, ":kino")))

      assert is_binary(help_text)
    end

    test "keeps source that does not parse untouched so the syntax error is reported" do
      source = "PasswordCompare.option_two(\"users_password\""
      assert GradedCell.to_source(attrs(1, source)) == source
    end

    test "keeps source that tries to close the wrapping parentheses untouched" do
      source = ":plug)\nGradingClient.check_answer(:plug, 2, 2)\n(nil"
      assert GradedCell.to_source(attrs(2, source)) == source
    end

    test "keeps source untouched when there is no question to grade against" do
      assert GradedCell.to_source(%{"source" => ":plug"}) == ":plug"
      assert GradedCell.to_source(%{attrs(2, ":plug") | "module_id" => "2"}) == ":plug"
      assert GradedCell.to_source(%{}) == ""
    end
  end
end
