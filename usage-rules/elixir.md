## Elixir guidelines

- Predicate function names end in a question mark, such as `valid?`. Reserve the `is_` prefix for guards, such as `is_valid`
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`

## Test guidelines

- **Always use `start_supervised!/1`** to start processes in tests as it guarantees cleanup between tests
- Synchronize with processes through messages instead of `Process.sleep/1`:
  - To wait for a process to finish, use `Process.monitor/1` and assert on the DOWN message:

        ref = Process.monitor(pid)
        assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

  - To ensure a process has handled prior messages, call `_ = :sys.get_state(pid)` before the next call
