alias GradingClient.Answer

to_answers = fn module_name, answers ->
  Enum.map(answers, fn data ->
    %Answer{
      module_id: module_name,
      question_id: data.question_id,
      answer: data.answer,
      help_text: data[:help_text]
    }
  end)
end

owasp_questions = [
  %{
    question_id: 1,
    answer: :entry_granted_op2,
    help_text:
      "MD5 is a broken, unsalted hashing algorithm. Look for the option that uses a salted hashing function with a delay factor."
  },
  %{
    question_id: 2,
    answer: :plug,
    help_text:
      "Look at the dependencies installed in the very first cell. One of them is pinned to a much older version than the rest."
  }
]

List.flatten([
  to_answers.(OWASP, owasp_questions)
])
