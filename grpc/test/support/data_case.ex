defmodule GRPC.Client.DataCase do
  @moduledoc """
  This module defines the test case to be used by
  tests for grpc.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      import GRPC.Factory
      import GRPC.Client.DataCase
    end
  end

  @doc """
  Re-evaluates `block` until its assertions hold or `:timeout` (default 1s)
  elapses, re-raising the last failure on timeout.

  Prefer this over sleeping for a fixed duration: the test only waits as long
  as the condition actually takes to become true.
  """
  defmacro assert_eventually(opts \\ [], do: block) do
    quote do
      unquote(__MODULE__).retry_until_asserted(
        fn -> unquote(block) end,
        Keyword.get(unquote(opts), :timeout, 1_000)
      )
    end
  end

  @doc false
  def retry_until_asserted(fun, timeout) do
    retry_until_asserted(fun, System.monotonic_time(:millisecond) + timeout, 5)
  end

  defp retry_until_asserted(fun, deadline, interval) do
    fun.()
  rescue
    error in [ExUnit.AssertionError] ->
      if System.monotonic_time(:millisecond) < deadline do
        Process.sleep(interval)
        retry_until_asserted(fun, deadline, interval)
      else
        reraise(error, __STACKTRACE__)
      end
  end

  @doc """
  Attaches a telemetry handler for `event` that forwards emissions to the
  test process as `{:telemetry, event, measurements, metadata}` messages,
  for use with `assert_receive`. The handler is detached on test exit.
  """
  def attach_telemetry(event) do
    handler_id = {__MODULE__, self(), System.unique_integer()}
    test_pid = self()

    :telemetry.attach(
      handler_id,
      event,
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry, event, measurements, metadata})
      end,
      nil
    )

    ExUnit.Callbacks.on_exit(fn -> :telemetry.detach(handler_id) end)
  end
end
