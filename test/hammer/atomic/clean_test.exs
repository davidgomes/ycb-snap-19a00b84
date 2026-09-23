defmodule Hammer.Atomic.CleanTest do
  use ExUnit.Case, async: true

  defmodule RateAtomicLimit do
    use Hammer, backend: :atomic
  end

  defmodule RateAtomicLimitLeakyBucket do
    use Hammer, backend: :atomic, algorithm: :leaky_bucket
  end

  defmodule RateAtomicLimitTokenBucket do
    use Hammer, backend: :atomic, algorithm: :token_bucket
  end

  # Helper function to wait for a condition to be true
  defp eventually(fun, timeout \\ 5000, interval \\ 50) do
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

  test "cleaning works for fix window/default ets backend" do
    start_supervised!({RateAtomicLimit, clean_period: 50, key_older_than: 10})

    key = "key"
    scale = 100
    count = 10

    assert {:allow, 1} = RateAtomicLimit.hit(key, scale, count)

    assert [_] = :ets.tab2list(RateAtomicLimit)

    # Wait for cleanup to occur by polling the table
    eventually(fn ->
      :ets.tab2list(RateAtomicLimit) == []
    end)
  end

  test "cleaning works for token bucket" do
    start_supervised!({RateAtomicLimitTokenBucket, clean_period: 100, key_older_than: 1000})

    key = "key"
    refill_rate = 1
    capacity = 10

    assert {:allow, 9} = RateAtomicLimitTokenBucket.hit(key, refill_rate, capacity, 1)

    assert [_] = :ets.tab2list(RateAtomicLimitTokenBucket)

    # Wait for cleanup to occur by polling the table
    eventually(fn ->
      :ets.tab2list(RateAtomicLimitTokenBucket) == []
    end)
  end

  test "cleaning works for leaky bucket" do
    start_supervised!({RateAtomicLimitLeakyBucket, clean_period: 100, key_older_than: 1000})

    key = "key"
    leak_rate = 1
    capacity = 10

    assert {:allow, 1} = RateAtomicLimitLeakyBucket.hit(key, leak_rate, capacity, 1)

    assert [_] = :ets.tab2list(RateAtomicLimitLeakyBucket)

    # Wait for cleanup to occur by polling the table
    eventually(fn ->
      :ets.tab2list(RateAtomicLimitLeakyBucket) == []
    end)
  end

  describe "before_clean" do
    test "is invoked with expired fix window entries before deletion" do
      test_pid = self()

      start_supervised!(
        {RateAtomicLimit,
         clean_period: 50,
         key_older_than: 10,
         before_clean: fn algorithm, entries -> send(test_pid, {:cleaned, algorithm, entries}) end}
      )

      assert {:allow, 1} = RateAtomicLimit.hit("key", 100, 10)

      assert_receive {:cleaned, :fix_window, [%{key: "key", value: 1, expired_at: expired_at}]},
                     2000

      assert is_integer(expired_at)
      eventually(fn -> :ets.tab2list(RateAtomicLimit) == [] end)
    end

    test "supports MFA callbacks for token bucket" do
      start_supervised!(
        {RateAtomicLimitTokenBucket,
         clean_period: 100, key_older_than: 1000, before_clean: {__MODULE__, :forward, [self()]}}
      )

      assert {:allow, 9} = RateAtomicLimitTokenBucket.hit("key", 1, 10, 1)

      assert_receive {:cleaned, :token_bucket, [%{key: "key", value: 9}]}, 5000
      eventually(fn -> :ets.tab2list(RateAtomicLimitTokenBucket) == [] end)
    end

    test "is invoked with expired leaky bucket entries" do
      start_supervised!(
        {RateAtomicLimitLeakyBucket,
         clean_period: 100, key_older_than: 1000, before_clean: {__MODULE__, :forward, [self()]}}
      )

      assert {:allow, 1} = RateAtomicLimitLeakyBucket.hit("key", 1, 10, 1)

      assert_receive {:cleaned, :leaky_bucket, [%{key: "key", value: 1}]}, 5000
      eventually(fn -> :ets.tab2list(RateAtomicLimitLeakyBucket) == [] end)
    end

    @tag :capture_log
    test "entries are still deleted when the callback raises" do
      start_supervised!(
        {RateAtomicLimit,
         clean_period: 50,
         key_older_than: 10,
         before_clean: fn _algorithm, _entries -> raise "boom" end}
      )

      assert {:allow, 1} = RateAtomicLimit.hit("key", 100, 10)
      eventually(fn -> :ets.tab2list(RateAtomicLimit) == [] end)
    end
  end

  def forward(algorithm, entries, pid), do: send(pid, {:cleaned, algorithm, entries})
end
