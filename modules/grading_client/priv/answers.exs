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
      "Revisit the Prevention list for Cryptographic Failures: which of these hashing algorithms is deprecated, and which one is salted with a delay factor?"
  },
  %{
    question_id: 2,
    answer: :plug,
    help_text:
      "Take a closer look at the version requirements in the setup cell at the top of this Livebook. One of them pins a package to a long-outdated release line with published security advisories."
  }
]

List.flatten([
  to_answers.("OWASP", owasp_questions)
])
