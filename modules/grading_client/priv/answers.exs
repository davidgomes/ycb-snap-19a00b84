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
    help_text: "MD5 is a deprecated hashing function. Prefer a salted, slow hash such as bcrypt."
  },
  %{
    question_id: 2,
    answer: :plug,
    help_text: "Check the version of :plug pinned in the first cell of this Livebook."
  }
]

List.flatten([
  to_answers.(OWASP, owasp_questions)
])
