## Elixir guidelines

- Access struct fields directly (`my_struct.field`) or through the struct's own APIs, such as `Ecto.Changeset.get_field/2` for changesets. Structs do not implement the `Access` behaviour, so `my_struct[:field]` fails at runtime
- Name predicate functions with a trailing question mark (`valid?/1`) and reserve the `is_` prefix for guards
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure, usually passing `timeout: :infinity`

## Mix guidelines

- Read the docs and options of a task with `mix help task_name` before using it

## Test guidelines

- Start processes in tests with `start_supervised!/1`, which guarantees cleanup between tests
- Synchronize with processes through messages instead of `Process.sleep/1` or `Process.alive?/1`:
  - To wait for a process to exit, monitor it and assert on the DOWN message: `ref = Process.monitor(pid)` then `assert_receive {:DOWN, ^ref, :process, ^pid, :normal}`
  - To ensure a process has handled prior messages before the next call, use `_ = :sys.get_state(pid)`
