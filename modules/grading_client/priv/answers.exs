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
      "MD5 is a fast, unsalted and deprecated hashing algorithm. Re-read the Cryptographic Failures prevention list: passwords should be stored using strong, salted hashing functions with a delay factor."
  },
  %{
    question_id: 2,
    answer: fn
      {:plug, version} when is_list(version) ->
        Version.match?(List.to_string(version), ">= 1.4.0")

      _ ->
        false
    end,
    help_text:
      "Look for the dependency in the setup cell that is pinned to a very old release. Once you have found it, update it to a current version in the setup cell, reconnect and run the setup cell again, then re-run this cell."
  }
]

List.flatten([
  to_answers.(OWASP, owasp_questions)
])
