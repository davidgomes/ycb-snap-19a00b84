## Elixir guidelines

- Use `Enum.at/2`, pattern matching, or `List` functions for index based list access, as lists do not support the access syntax (`mylist[i]`)
- Variables rebound inside block expressions like `if`, `case`, and `cond` are not visible outside of them, so **always** bind the result of the whole expression instead: `socket = if connected?(socket), do: assign(socket, :val, val), else: socket`
- Access struct fields directly, such as `my_struct.field`, or through higher level APIs such as `Ecto.Changeset.get_field/2`, as structs do not implement the Access behaviour (`my_struct[:field]`) by default
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`

## Test guidelines

- **Always use `start_supervised!/1`** to start processes in tests as it guarantees cleanup between tests
- Synchronize with processes instead of sleeping: wait for a process to exit with `ref = Process.monitor(pid)` and `assert_receive {:DOWN, ^ref, :process, ^pid, :normal}`, and use `_ = :sys.get_state(pid)` to ensure a process has handled prior messages
