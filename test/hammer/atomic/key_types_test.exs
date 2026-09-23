defmodule Hammer.Atomic.KeyTypesTest do
  use ExUnit.Case, async: true

  defmodule RateLimitFixWindow do
    use Hammer, backend: :atomic, algorithm: :fix_window
  end

  defmodule RateLimitLeakyBucket do
    use Hammer, backend: :atomic, algorithm: :leaky_bucket
  end

  defmodule RateLimitTokenBucket do
    use Hammer, backend: :atomic, algorithm: :token_bucket
  end

  @keys ["user:42", :user_42, 42, {:user, 42}, [:user, 42], %{user_id: 42}]

  test "fix window accepts any term as key" do
    start_supervised!(RateLimitFixWindow)
    scale = :timer.minutes(10)
    limit = 3

    for key <- @keys do
      assert RateLimitFixWindow.get(key, scale) == 0
      assert {:allow, 1} = RateLimitFixWindow.hit(key, scale, limit)
      assert RateLimitFixWindow.inc(key, scale) == 2
      assert {:allow, 3} = RateLimitFixWindow.hit(key, scale, limit)
      assert {:deny, _retry_after} = RateLimitFixWindow.hit(key, scale, limit)
      assert RateLimitFixWindow.set(key, scale, 1) == 1
      assert RateLimitFixWindow.get(key, scale) == 1
    end
  end

  test "leaky bucket accepts any term as key" do
    start_supervised!(RateLimitLeakyBucket)
    leak_rate = 1
    capacity = 2

    for key <- @keys do
      assert RateLimitLeakyBucket.get(key, leak_rate) == 0
      assert {:allow, 1} = RateLimitLeakyBucket.hit(key, leak_rate, capacity, 1)
      assert {:allow, 2} = RateLimitLeakyBucket.hit(key, leak_rate, capacity, 1)
      assert RateLimitLeakyBucket.get(key, leak_rate) == 2
      assert {:deny, _retry_after} = RateLimitLeakyBucket.hit(key, leak_rate, capacity, 1)
    end
  end

  test "token bucket accepts any term as key" do
    start_supervised!(RateLimitTokenBucket)
    refill_rate = 1
    capacity = 2

    for key <- @keys do
      assert {:allow, 1} = RateLimitTokenBucket.hit(key, refill_rate, capacity, 1)
      assert {:allow, 0} = RateLimitTokenBucket.hit(key, refill_rate, capacity, 1)
      assert RateLimitTokenBucket.get(key, refill_rate) == 0
      assert {:deny, _retry_after} = RateLimitTokenBucket.hit(key, refill_rate, capacity, 1)
    end
  end
end
