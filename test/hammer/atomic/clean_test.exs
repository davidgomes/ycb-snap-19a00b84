defmodule Hammer.Atomic.CleanTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Hammer.CleanTestHelpers

  defmodule RateAtomicLimit do
    use Hammer, backend: :atomic
  end

  defmodule RateAtomicLimitLeakyBucket do
    use Hammer, backend: :atomic, algorithm: :leaky_bucket
  end

  defmodule RateAtomicLimitTokenBucket do
    use Hammer, backend: :atomic, algorithm: :token_bucket
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
    test "receives expired fix window entries" do
      start_supervised!(
        {RateAtomicLimit, clean_period: 50, key_older_than: 10, before_clean: notify(self())}
      )

      assert {:allow, 3} = RateAtomicLimit.hit("key", 100, 10, 3)

      assert_receive {:before_clean, :fix_window, [entry]}, 1000
      assert %{key: "key", count: 3, expires_at: expires_at} = entry
      assert is_integer(expires_at)

      eventually(fn -> :ets.tab2list(RateAtomicLimit) == [] end)
    end

    test "receives expired token bucket entries" do
      start_supervised!(
        {RateAtomicLimitTokenBucket,
         clean_period: 100, key_older_than: 1000, before_clean: notify(self())}
      )

      assert {:allow, 9} = RateAtomicLimitTokenBucket.hit("key", 1, 10, 1)

      assert_receive {:before_clean, :token_bucket, [entry]}, 5000
      assert %{key: "key", level: 9, last_update: last_update} = entry
      assert is_integer(last_update)

      eventually(fn -> :ets.tab2list(RateAtomicLimitTokenBucket) == [] end)
    end

    test "receives expired leaky bucket entries" do
      start_supervised!(
        {RateAtomicLimitLeakyBucket,
         clean_period: 100, key_older_than: 1000, before_clean: notify(self())}
      )

      assert {:allow, 1} = RateAtomicLimitLeakyBucket.hit("key", 1, 10, 1)

      assert_receive {:before_clean, :leaky_bucket, [entry]}, 5000
      assert %{key: "key", level: 1, last_update: last_update} = entry
      assert is_integer(last_update)

      eventually(fn -> :ets.tab2list(RateAtomicLimitLeakyBucket) == [] end)
    end

    test "is not invoked when nothing expired" do
      limiters = [RateAtomicLimit, RateAtomicLimitTokenBucket, RateAtomicLimitLeakyBucket]

      for limiter <- limiters do
        start_supervised!({limiter, clean_period: 50, before_clean: notify(self())})
      end

      assert {:allow, 1} = RateAtomicLimit.hit("key", 100, 10)
      assert {:allow, 9} = RateAtomicLimitTokenBucket.hit("key", 1, 10, 1)
      assert {:allow, 1} = RateAtomicLimitLeakyBucket.hit("key", 1, 10, 1)

      refute_receive {:before_clean, _algorithm, _entries}, 300

      for limiter <- limiters do
        assert [_] = :ets.tab2list(limiter)
      end
    end

    test "logs a warning and still deletes entries when the callback raises" do
      start_supervised!(
        {RateAtomicLimit,
         clean_period: 50, key_older_than: 10, before_clean: fn _, _ -> raise "boom" end}
      )

      log =
        capture_log(fn ->
          assert {:allow, 1} = RateAtomicLimit.hit("key", 100, 10)
          eventually(fn -> :ets.tab2list(RateAtomicLimit) == [] end)
        end)

      assert log =~ "before_clean callback failed"
      assert log =~ "boom"
    end

    test "accepts a {module, function, args} callback" do
      start_supervised!(
        {RateAtomicLimit,
         clean_period: 50,
         key_older_than: 10,
         before_clean: {Hammer.CleanTestHelpers, :notify_mfa, [self()]}}
      )

      assert {:allow, 1} = RateAtomicLimit.hit("key", 100, 10)

      assert_receive {:before_clean_mfa, :fix_window, [%{key: "key", count: 1}]}, 1000
    end

    test "keeps entries hit while the callback runs" do
      test_pid = self()

      callback = fn :token_bucket, entries ->
        RateAtomicLimitTokenBucket.hit("key", 1, 10, 1)
        send(test_pid, {:before_clean, entries})
      end

      pid =
        start_supervised!(
          {RateAtomicLimitTokenBucket,
           clean_period: 100, key_older_than: 1000, before_clean: callback}
        )

      assert {:allow, 9} = RateAtomicLimitTokenBucket.hit("key", 1, 10, 1)

      assert_receive {:before_clean, [%{key: "key"}]}, 5000
      :sys.get_state(pid)
      assert [{"key", _atomic}] = :ets.tab2list(RateAtomicLimitTokenBucket)
    end

    test "rejects an invalid callback" do
      assert_raise ArgumentError, ~r/:before_clean/, fn ->
        RateAtomicLimit.start_link(before_clean: {:not, "a", :callback})
      end
    end
  end
end
