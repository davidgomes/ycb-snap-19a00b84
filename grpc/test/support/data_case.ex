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

  @doc """
  Polls `fun` until it returns a truthy value, failing the test if that
  doesn't happen within `timeout` milliseconds.
  """
  def wait_until(fun, timeout \\ 1_000) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_wait_until(fun, deadline)
  end

  defp do_wait_until(fun, deadline) do
    cond do
      fun.() ->
        :ok

      System.monotonic_time(:millisecond) > deadline ->
        ExUnit.Assertions.flunk("condition was not met in time")

      true ->
        Process.sleep(5)
        do_wait_until(fun, deadline)
    end
  end
end
