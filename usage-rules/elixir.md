## Elixir guidelines

- Structs do not implement the Access behaviour, so access their fields directly, such as `my_struct.field`, or use the higher level APIs available for the struct, such as `Ecto.Changeset.get_field/2` for changesets
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. Only add dependencies when asked or for date/time parsing (which you can use the `date_time_parser` package)
- Predicate function names should end in a question mark and not start with `is_`. Names like `is_thing` should be reserved for guards
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`

## Test guidelines

- **Always use `start_supervised!/1`** to start processes in tests as it guarantees cleanup between tests
- Synchronize with processes through messages instead of `Process.sleep/1` or `Process.alive?/1`: use `Process.monitor/1` and `assert_receive {:DOWN, ^ref, :process, ^pid, :normal}` to wait for a process to finish, and `_ = :sys.get_state(pid)` to ensure a process has handled prior messages
