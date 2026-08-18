defmodule ObanEvents.Testing do
  @moduledoc """
  Testing helpers for assertions on events and handlers with ObanEvents.

  Provides convenient test helpers for verifying events emitted, enqueued jobs,
  and executing handlers in unit and integration tests.

  ## Usage

  In your test module or test case template:

      use ObanEvents.Testing

  Or import the module directly:

      import ObanEvents.Testing
  """

  import ExUnit.Assertions

  @doc """
  Helper macro to import or use ObanEvents testing utilities.
  """
  defmacro __using__(_opts) do
    quote do
      import ObanEvents.Testing
    end
  end

  @doc """
  Asserts that an event was enqueued for dispatch via `ObanEvents.DispatchWorker`.

  ## Options

  - `:event` - (atom or string) The expected event name
  - `:handler` - (module or string) Expected handler module
  - `:data` - Expected data map or subset to match
  - `:metadata` - Expected metadata map to match

  ## Examples

      assert_event_enqueued(:user_created)
      assert_event_enqueued(:user_created, handler: MyApp.EmailHandler)
      assert_event_enqueued(:user_created, data: %{"user_id" => 123})
  """
  defmacro assert_event_enqueued(event_name, opts \\ []) do
    quote do
      event_str = to_string(unquote(event_name))
      opts = unquote(opts)
      expected_handler = Keyword.get(opts, :handler)
      expected_data = Keyword.get(opts, :data)
      expected_metadata = Keyword.get(opts, :metadata)

      # When Oban.Testing is available
      expected_args =
        %{"event" => event_str}
        |> maybe_put_expected("handler", expected_handler && to_string(expected_handler))
        |> maybe_put_expected("data", expected_data)
        |> maybe_put_expected("metadata", expected_metadata)

      # Use Oban.Testing.assert_enqueued if available
      Oban.Testing.assert_enqueued(
        worker: ObanEvents.DispatchWorker,
        args: expected_args
      )
    end
  end

  @doc """
  Refutes that an event was enqueued for dispatch via `ObanEvents.DispatchWorker`.

  ## Examples

      refute_event_enqueued(:user_created)
      refute_event_enqueued(:user_created, handler: MyApp.EmailHandler)
  """
  defmacro refute_event_enqueued(event_name, opts \\ []) do
    quote do
      event_str = to_string(unquote(event_name))
      opts = unquote(opts)
      expected_handler = Keyword.get(opts, :handler)
      expected_data = Keyword.get(opts, :data)
      expected_metadata = Keyword.get(opts, :metadata)

      expected_args =
        %{"event" => event_str}
        |> maybe_put_expected("handler", expected_handler && to_string(expected_handler))
        |> maybe_put_expected("data", expected_data)
        |> maybe_put_expected("metadata", expected_metadata)

      Oban.Testing.refute_enqueued(
        worker: ObanEvents.DispatchWorker,
        args: expected_args
      )
    end
  end

  @doc """
  Executes a handler module directly for unit testing.
  Supports both `(handler_module, event_name, data)` and `(handler_module, event_name, data, metadata)`.

  ## Examples

      perform_handler(MyApp.EmailHandler, :user_created, %{"user_id" => 123})
      # => :ok

      perform_handler(MyApp.EmailHandler, :user_created, %{"user_id" => 123}, %{"request_id" => "123"})
      # => :ok
  """
  @spec perform_handler(module(), atom(), map(), map()) :: :ok | {:ok, any()} | {:error, any()}
  def perform_handler(handler_module, event_name, data \\ %{}, metadata \\ %{})
      when is_atom(handler_module) and is_atom(event_name) and is_map(data) and is_map(metadata) do
    if function_exported?(handler_module, :handle_event, 3) do
      handler_module.handle_event(event_name, data, metadata)
    else
      handler_module.handle_event(event_name, data)
    end
  end

  @doc false
  def maybe_put_expected(map, _key, nil), do: map
  def maybe_put_expected(map, key, value), do: Map.put(map, key, value)
end
