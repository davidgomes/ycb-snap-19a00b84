defmodule GradingClient do
  @moduledoc """
  Module used for checking answers to questions.
  """

  @doc """
  Checks the answer to a question.
  """

  @spec check_answer(any(), any(), any()) :: :correct | {:incorrect, String.t() | nil}
  def check_answer(answer, module_id, question_id) do
    GradingClient.Answers.check(module_id, question_id, answer)
  end

  @doc """
  Checks the answer to a question and prints feedback for the learner.
  """

  @spec self_evaluate(any(), any(), any()) :: :correct | {:incorrect, String.t() | nil}
  def self_evaluate(answer, module_id, question_id) do
    result = check_answer(answer, module_id, question_id)

    case result do
      :correct ->
        IO.puts([IO.ANSI.green(), "Correct!", IO.ANSI.reset()])

      {:incorrect, help_text} when is_binary(help_text) ->
        IO.puts([IO.ANSI.red(), "Incorrect: ", IO.ANSI.reset(), help_text])

      {:incorrect, _help_text} ->
        IO.puts([IO.ANSI.red(), "Incorrect.", IO.ANSI.reset()])
    end

    result
  end
end
