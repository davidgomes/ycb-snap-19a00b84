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
      "Uncomment exactly one function call. MD5 is a fast, unsalted hash that is no longer considered safe for passwords - revisit the Cryptographic Failures prevention list for better options."
  },
  %{
    question_id: 2,
    answer: :plug,
    help_text:
      "Check the version requirements in the setup cell at the top of this notebook. One package is locked to a release line that reached end-of-life years ago and has published security advisories."
  }
]

List.flatten([
  to_answers.(2, owasp_questions)
])
