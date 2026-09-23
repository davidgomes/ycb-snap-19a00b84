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
      "MD5 is a fast, unsalted hash that is considered broken for password storage. Prefer a salted, slow hashing function like bcrypt."
  },
  %{
    question_id: 2,
    answer: :plug,
    help_text:
      "Check the versions of the dependencies installed at the top of this Livebook against their published security advisories."
  }
]

List.flatten([
  to_answers.(OWASP, owasp_questions)
])
