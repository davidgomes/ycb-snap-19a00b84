## Elixir guidelines

- Elixir lists **do not support index based access via the access syntax** (`mylist[i]` is invalid). **Always** use `Enum.at/2`, pattern matching, or `List` functions instead
- Elixir variables are immutable, but can be rebound. For block expressions like `if`, `case`, `cond`, etc. you *must* bind the result of the expression to a variable, as rebinding inside the expression has no effect outside of it:

      # INVALID: the rebinding inside the `if` is lost
      if connected?(socket) do
        socket = assign(socket, :val, val)
      end

      # VALID: we bind the result of the `if`
      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        else
          socket
        end

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors
- **Never** use map access syntax (`struct[:field]`) on structs as they do not implement the `Access` behaviour by default. Access the fields directly, such as `my_struct.field`, or use higher level APIs when available, such as `Ecto.Changeset.get_field/2` for changesets
- Use the standard library's `Time`, `Date`, `DateTime`, and `Calendar` modules for date and time manipulation. **Never** install additional dependencies for it unless asked or for date/time parsing (use the `date_time_parser` package)
- **Never** use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should end in a question mark and not start with `is_`. Names like `is_thing` are reserved for guards
- OTP primitives like `DynamicSupervisor` and `Registry` require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, which you then use to call them: `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. Most of the time you will want to pass `timeout: :infinity`

## Mix guidelines

- Read the docs and options of a task with `mix help task_name` before using it
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or rerun previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason

## Test guidelines

- **Always use `start_supervised!/1`** to start processes in tests as it guarantees cleanup between tests
- **Avoid** `Process.sleep/1` and `Process.alive?/1` in tests:
  - To wait for a process to finish, monitor it with `ref = Process.monitor(pid)` and assert on the DOWN message with `assert_receive {:DOWN, ^ref, :process, ^pid, :normal}`
  - To synchronize before the next call, use `_ = :sys.get_state(pid)` to ensure the process has handled prior messages
