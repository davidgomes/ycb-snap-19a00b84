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
      "MD5 is a fast, unsalted and broken hashing algorithm. Look for the option using a slow, salted algorithm built for passwords."
  },
  %{
    question_id: 2,
    answer: :plug,
    help_text:
      "Compare the versions pinned in the very first cell against the latest releases on hex.pm - one of them is several years out of date."
  }
]

List.flatten([
  to_answers.(OWASP, owasp_questions)
])
