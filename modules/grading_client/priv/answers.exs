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
      "MD5 is a fast, unsalted and deprecated hash. Prefer a salted hashing function with a work factor, such as Bcrypt."
  },
  %{
    question_id: 2,
    answer: :plug,
    help_text:
      "Look at the versions pinned in the Mix.install/2 call at the top of this Livebook and check them for known vulnerabilities."
  }
]

List.flatten([
  to_answers.(OWASP, owasp_questions)
])
