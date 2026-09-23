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
      "MD5 is a deprecated hashing algorithm. Look for a strong, salted hashing function with a delay factor."
  },
  %{
    question_id: 2,
    answer: :plug,
    help_text:
      "Compare the versions of each dependency installed at the top of this module against their latest releases and known security advisories."
  }
]

List.flatten([
  to_answers.(OWASP, owasp_questions)
])
