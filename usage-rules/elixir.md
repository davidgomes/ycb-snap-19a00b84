## Elixir guidelines

- Access list elements by index with `Enum.at/2`, pattern matching, or the `List` module, since lists do not implement the Access behaviour
- Bind the result of block expressions like `if`, `case`, and `cond` to use values computed inside them, as rebinding inside the block has no effect outside of it:

      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        else
          socket
        end

- Define one module per file to avoid cyclic dependencies
- Access struct fields directly (`my_struct.field`) or through the struct's own APIs, such as `Ecto.Changeset.get_field/2` for changesets, since structs do not implement the Access behaviour
- Use the standard library's `Time`, `Date`, `DateTime`, and `Calendar` modules for date and time manipulation, adding dependencies only when asked or for date/time parsing (with the `date_time_parser` package)
- Name predicate functions with a trailing question mark (`valid?`), reserving the `is_` prefix for guards
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure, usually passing `timeout: :infinity`

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`

## Test guidelines

- Start processes in tests with `start_supervised!/1`, which guarantees cleanup between tests
- Synchronize with processes through messages rather than `Process.sleep/1` or `Process.alive?/1`:
  - To wait for a process to finish, monitor it and assert on the DOWN message:

        ref = Process.monitor(pid)
        assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

  - To ensure a process has handled prior messages, call `_ = :sys.get_state(pid)`
