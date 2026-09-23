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
      "MD5 is a fast, unsalted and broken hashing algorithm. Prefer a salted, slow password hashing function such as bcrypt."
  },
  %{
    question_id: 2,
    answer: :plug,
    help_text:
      "Look at the version requirements in the setup cell - one package is held back on a release line from 2017 with known security advisories."
  }
]

List.flatten([
  to_answers.(OWASP, owasp_questions)
])
