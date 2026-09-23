defmodule Hammer.ETS.CleanTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Hammer.CleanTestHelpers

  defmodule RateLimit do
    use Hammer, backend: :ets
  end

  defmodule RateLimitSlidingWindow do
    use Hammer, backend: :ets, algorithm: :sliding_window
  end

  defmodule RateLimitLeakyBucket do
    use Hammer, backend: :ets, algorithm: :leaky_bucket
  end

  defmodule RateLimitTokenBucket do
    use Hammer, backend: :ets, algorithm: :token_bucket
  end

  test "cleaning works for fix window/default ets backend" do
    start_supervised!({RateLimit, clean_period: 100})

    key = "key"
    scale = 100
    count = 10

    assert {:allow, 1} = RateLimit.hit(key, scale, count)

    assert [_] = :ets.tab2list(RateLimit)

    # Wait for cleanup to occur by polling the table
    eventually(fn ->
      :ets.tab2list(RateLimit) == []
    end)
  end

  test "cleaning works for sliding window" do
    start_supervised!({RateLimitSlidingWindow, clean_period: 100})

    key = "key"
    scale = 100
    count = 10

    assert {:allow, 1} = RateLimitSlidingWindow.hit(key, scale, count)

    assert [_] = :ets.tab2list(RateLimitSlidingWindow)

    # Wait for cleanup to occur by polling the table
    eventually(fn ->
      :ets.tab2list(RateLimitSlidingWindow) == []
    end)
  end

  test "cleaning works for token bucket" do
    start_supervised!({RateLimitTokenBucket, clean_period: 100, key_older_than: 1000})

    key = "key"
    refill_rate = 1
    capacity = 10

    assert {:allow, 9} = RateLimitTokenBucket.hit(key, refill_rate, capacity, 1)

    assert [_] = :ets.tab2list(RateLimitTokenBucket)

    # Wait for cleanup to occur by polling the table
    eventually(fn ->
      :ets.tab2list(RateLimitTokenBucket) == []
    end)
  end

  test "cleaning works for leaky bucket" do
    start_supervised!({RateLimitLeakyBucket, clean_period: 100, key_older_than: 1000})

    key = "key"
    leak_rate = 1
    capacity = 10

    assert {:allow, 1} = RateLimitLeakyBucket.hit(key, leak_rate, capacity, 1)

    assert [_] = :ets.tab2list(RateLimitLeakyBucket)

    # Wait for cleanup to occur by polling the table
    eventually(fn ->
      :ets.tab2list(RateLimitLeakyBucket) == []
    end)
  end

  describe "before_clean" do
    test "receives expired fix window entries" do
      start_supervised!({RateLimit, clean_period: 100, before_clean: notify(self())})

      assert {:allow, 3} = RateLimit.hit("key", 100, 10, 3)

      assert_receive {:before_clean, :fix_window, [entry]}, 1000
      assert %{key: "key", count: 3, expires_at: expires_at} = entry
      assert is_integer(expires_at)

      eventually(fn -> :ets.tab2list(RateLimit) == [] end)
    end

    test "receives expired sliding window hits counted per key" do
      start_supervised!({RateLimitSlidingWindow, clean_period: 200, before_clean: notify(self())})

      assert {:allow, 1} = RateLimitSlidingWindow.hit("a", 50, 10)
      # hits are stored under their microsecond timestamp
      Process.sleep(1)
      assert {:allow, 2} = RateLimitSlidingWindow.hit("a", 50, 10)
      assert {:allow, 1} = RateLimitSlidingWindow.hit("b", 50, 10)

      assert_receive {:before_clean, :sliding_window, entries}, 1000
      assert Enum.sort_by(entries, & &1.key) == [%{key: "a", count: 2}, %{key: "b", count: 1}]

      eventually(fn -> :ets.tab2list(RateLimitSlidingWindow) == [] end)
    end

    test "receives expired token bucket entries" do
      start_supervised!(
        {RateLimitTokenBucket,
         clean_period: 100, key_older_than: 1000, before_clean: notify(self())}
      )

      assert {:allow, 9} = RateLimitTokenBucket.hit("key", 1, 10, 1)

      assert_receive {:before_clean, :token_bucket, [entry]}, 5000
      assert %{key: "key", level: 9, last_update: last_update} = entry
      assert is_integer(last_update)

      eventually(fn -> :ets.tab2list(RateLimitTokenBucket) == [] end)
    end

    test "receives expired leaky bucket entries" do
      start_supervised!(
        {RateLimitLeakyBucket,
         clean_period: 100, key_older_than: 1000, before_clean: notify(self())}
      )

      assert {:allow, 1} = RateLimitLeakyBucket.hit("key", 1, 10, 1)

      assert_receive {:before_clean, :leaky_bucket, [entry]}, 5000
      assert %{key: "key", level: 1, last_update: last_update} = entry
      assert is_integer(last_update)

      eventually(fn -> :ets.tab2list(RateLimitLeakyBucket) == [] end)
    end

    test "is not invoked when nothing expired" do
      for limiter <- [
            RateLimit,
            RateLimitSlidingWindow,
            RateLimitTokenBucket,
            RateLimitLeakyBucket
          ] do
        start_supervised!({limiter, clean_period: 50, before_clean: notify(self())})
      end

      assert {:allow, 1} = RateLimit.hit("key", :timer.hours(1), 10)
      assert {:allow, 1} = RateLimitSlidingWindow.hit("key", :timer.minutes(1), 10)
      assert {:allow, 9} = RateLimitTokenBucket.hit("key", 1, 10, 1)
      assert {:allow, 1} = RateLimitLeakyBucket.hit("key", 1, 10, 1)

      refute_receive {:before_clean, _algorithm, _entries}, 300

      for limiter <- [
            RateLimit,
            RateLimitSlidingWindow,
            RateLimitTokenBucket,
            RateLimitLeakyBucket
          ] do
        assert [_] = :ets.tab2list(limiter)
      end
    end

    test "logs a warning and still deletes entries when the callback raises" do
      start_supervised!({RateLimit, clean_period: 100, before_clean: fn _, _ -> raise "boom" end})

      log =
        capture_log(fn ->
          assert {:allow, 1} = RateLimit.hit("key", 100, 10)
          eventually(fn -> :ets.tab2list(RateLimit) == [] end)
        end)

      assert log =~ "before_clean callback failed"
      assert log =~ "boom"
    end

    test "accepts a {module, function, args} callback" do
      start_supervised!(
        {RateLimit,
         clean_period: 100, before_clean: {Hammer.CleanTestHelpers, :notify_mfa, [self()]}}
      )

      assert {:allow, 1} = RateLimit.hit("key", 100, 10)

      assert_receive {:before_clean_mfa, :fix_window, [%{key: "key", count: 1}]}, 1000
    end

    test "keeps entries hit while the callback runs" do
      test_pid = self()

      callback = fn :token_bucket, entries ->
        RateLimitTokenBucket.hit("key", 1, 10, 1)
        send(test_pid, {:before_clean, entries})
      end

      pid =
        start_supervised!(
          {RateLimitTokenBucket, clean_period: 100, key_older_than: 1000, before_clean: callback}
        )

      assert {:allow, 9} = RateLimitTokenBucket.hit("key", 1, 10, 1)

      assert_receive {:before_clean, [%{key: "key"}]}, 5000
      :sys.get_state(pid)
      assert [{"key", _level, _last_update}] = :ets.tab2list(RateLimitTokenBucket)
    end

    test "rejects an invalid callback" do
      assert_raise ArgumentError, ~r/:before_clean/, fn ->
        RateLimit.start_link(before_clean: fn _entries -> :ok end)
      end
    end
  end
end
