# GradingClient

Simple client that abstracts out the `grading_server` connection.

## Graded Cells

`GradingClient.GradedCell` is a smart cell for self-evaluated quiz questions. The learner
edits the code inside the cell; evaluating the cell runs that code and checks its result
against the answer stored in `priv/answers.exs` for the cell's `module_id` (the module
number, e.g. `2` for `2-owasp.livemd`) and `question_id`. It returns `:correct` or
`{:incorrect, help_text}`.

To add a graded question:

1. Add the expected answer and a hint to `priv/answers.exs`.
2. Add the cell to the module's `.livemd` file. Livebook accepts the attributes as plain
   JSON and re-encodes them the next time the notebook is saved. The `elixir` code block is
   regenerated from the attributes once the cell starts.

````markdown
<!-- livebook:{"attrs":{"module_id":2,"question_id":1,"source":"answer = :change_me\n\nanswer"},"kind":"Elixir.GradingClient.GradedCell","livebook_object":"smart_cell"} -->

```elixir
```
````

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

