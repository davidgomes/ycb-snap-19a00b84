defmodule Hammer.ETS.CleanTest do
  use ExUnit.Case, async: true

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

  defp eventually(fun, attempts \\ 10, delay \\ 50)
  defp eventually(fun, 1, _delay), do: fun.()

  defp eventually(fun, attempts, delay) do
    fun.()
  rescue
    ExUnit.AssertionError ->
      Process.sleep(delay)
      eventually(fun, attempts - 1, delay)
  end

  test "cleaning works for fix window/default ets backend" do
    start_supervised!({RateLimit, clean_period: 100})

    key = "key"
    scale = 100
    count = 10

    assert {:allow, 1} = RateLimit.hit(key, scale, count)

    assert [_] = :ets.tab2list(RateLimit)

    eventually(fn ->
      assert :ets.tab2list(RateLimit) == []
    end)
  end

  test "cleaning works for sliding window" do
    start_supervised!({RateLimitSlidingWindow, clean_period: 100})

    key = "key"
    scale = 100
    count = 10

    assert {:allow, 1} = RateLimitSlidingWindow.hit(key, scale, count)

    assert [_] = :ets.tab2list(RateLimitSlidingWindow)

    eventually(fn ->
      assert :ets.tab2list(RateLimitSlidingWindow) == []
    end)
  end

  test "cleaning works for token bucket" do
    start_supervised!({RateLimitTokenBucket, clean_period: 100})

    key = "key"
    refill_rate = 1
    capacity = 10

    assert {:allow, 9} = RateLimitTokenBucket.hit(key, refill_rate, capacity, 1)

    assert [_] = :ets.tab2list(RateLimitTokenBucket)

    eventually(fn ->
      assert :ets.tab2list(RateLimitTokenBucket) == []
    end)
  end

  test "cleaning works for leaky bucket" do
    start_supervised!({RateLimitLeakyBucket, clean_period: 100})

    key = "key"
    leak_rate = 1
    capacity = 10

    assert {:allow, 1} = RateLimitLeakyBucket.hit(key, leak_rate, capacity, 1)

    assert [_] = :ets.tab2list(RateLimitLeakyBucket)

    eventually(fn ->
      assert :ets.tab2list(RateLimitLeakyBucket) == []
    end)
  end
end
