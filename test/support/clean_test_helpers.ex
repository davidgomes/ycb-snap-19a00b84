defmodule Hammer.CleanTestHelpers do
  @moduledoc false

  import ExUnit.Assertions

  @doc """
  Polls `fun` until it returns a truthy value, failing the test after `timeout` milliseconds.
  """
  def eventually(fun, timeout \\ 5000, interval \\ 50) do
    eventually(fun, timeout, interval, System.monotonic_time(:millisecond))
  end

  defp eventually(fun, timeout, interval, start_time) do
    if fun.() do
      :ok
    else
      now = System.monotonic_time(:millisecond)

      if now - start_time > timeout do
        flunk("Condition not met within #{timeout}ms")
      else
        Process.sleep(interval)
        eventually(fun, timeout, interval, start_time)
      end
    end
  end

  @doc """
  Returns a `before_clean` callback that sends `{:before_clean, algorithm, entries}` to `pid`.
  """
  def notify(pid) do
    fn algorithm, entries -> send(pid, {:before_clean, algorithm, entries}) end
  end

  @doc """
  `before_clean` target for `{Hammer.CleanTestHelpers, :notify_mfa, [pid]}`.
  """
  def notify_mfa(algorithm, entries, pid) do
    send(pid, {:before_clean_mfa, algorithm, entries})
  end
end
