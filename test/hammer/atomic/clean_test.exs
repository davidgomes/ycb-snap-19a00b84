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
    import ExUnit.CaptureLog

    def forward(algorithm, entries, pid), do: send(pid, {:mfa_before_clean, algorithm, entries})

    defp notify(pid),
      do: fn algorithm, entries -> send(pid, {:before_clean, algorithm, entries}) end

    test "is called with expired fix window entries" do
      start_supervised!(
        {RateAtomicLimit, clean_period: 50, key_older_than: 10, before_clean: notify(self())}
      )

      assert {:allow, 1} = RateAtomicLimit.hit("key", 100, 10)
      assert {:allow, 2} = RateAtomicLimit.hit("key", 100, 10)

      assert_receive {:before_clean, :fix_window,
                      [%{key: "key", window: _, count: 2, expires_at: _}]},
                     2000

      assert :ets.tab2list(RateAtomicLimit) == []
    end

    test "is called with expired token bucket entries" do
      start_supervised!(
        {RateAtomicLimitTokenBucket,
         clean_period: 100, key_older_than: 1000, before_clean: notify(self())}
      )

      assert {:allow, 9} = RateAtomicLimitTokenBucket.hit("key", 1, 10, 1)

      assert_receive {:before_clean, :token_bucket, [%{key: "key", tokens: 9, last_update: _}]},
                     4000

      assert :ets.tab2list(RateAtomicLimitTokenBucket) == []
    end

    test "is called with expired leaky bucket entries" do
      start_supervised!(
        {RateAtomicLimitLeakyBucket,
         clean_period: 100, key_older_than: 1000, before_clean: notify(self())}
      )

      assert {:allow, 1} = RateAtomicLimitLeakyBucket.hit("key", 1, 10, 1)

      assert_receive {:before_clean, :leaky_bucket, [%{key: "key", level: 1, last_update: _}]},
                     4000

      assert :ets.tab2list(RateAtomicLimitLeakyBucket) == []
    end

    test "accepts a {module, function, args} tuple" do
      start_supervised!(
        {RateAtomicLimit,
         clean_period: 50, key_older_than: 10, before_clean: {__MODULE__, :forward, [self()]}}
      )

      assert {:allow, 1} = RateAtomicLimit.hit("key", 100, 10)

      assert_receive {:mfa_before_clean, :fix_window, [%{key: "key", count: 1}]}, 2000
    end

    test "is not called when nothing expired" do
      start_supervised!({RateAtomicLimit, clean_period: 50, before_clean: notify(self())})

      refute_receive {:before_clean, _, _}, 300
    end

    test "entries are still removed when the callback raises" do
      log =
        capture_log(fn ->
          start_supervised!(
            {RateAtomicLimit,
             clean_period: 50, key_older_than: 10, before_clean: fn _, _ -> raise "boom" end}
          )

          assert {:allow, 1} = RateAtomicLimit.hit("key", 100, 10)

          eventually(fn -> :ets.tab2list(RateAtomicLimit) == [] end)
        end)

      assert log =~ ":before_clean callback failed"
      assert log =~ "boom"
    end

    test "rejects an invalid callback" do
      assert_raise ArgumentError, ~r/:before_clean/, fn ->
        RateAtomicLimit.start_link(before_clean: :not_a_callback)
      end
    end
  end
end
