# GradingClient

Simple client that abstracts out the `grading_server` connection.

## Graded Cells

Quiz questions in the modules use the "Graded Cell" smart cell, so learners can
evaluate their own answers: evaluating the cell checks the value of its code
against `priv/answers.exs` and prints either `Correct!` or a hint.

A graded cell is identified by the `module_id` and `question_id` stored in its
attributes, which must match an entry in `priv/answers.exs`:

```
<!-- livebook:{"attrs":{"module_id":"OWASP","question_id":1,"source":"# answer = :a"},"chunks":null,"kind":"Elixir.GradingClient.GradedCell","livebook_object":"smart_cell"} -->
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `grading_client` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:grading_client, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/grading_client>.

