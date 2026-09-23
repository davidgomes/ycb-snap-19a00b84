defmodule Hammer.TermKeysTest do
  use ExUnit.Case, async: true

  # Keys are hit one after another in the same table, so each one starting from
  # an empty counter also shows that distinct terms never share a counter.
  @keys ["user", :user, {:user, 1}, {:user, 2}, 42, [:user, 1], %{user: 1}]

  defmodule ETSFixWindow do
    use Hammer, backend: :ets, algorithm: :fix_window
  end

  defmodule ETSSlidingWindow do
    use Hammer, backend: :ets, algorithm: :sliding_window
  end

  defmodule ETSLeakyBucket do
    use Hammer, backend: :ets, algorithm: :leaky_bucket
  end

  defmodule ETSTokenBucket do
    use Hammer, backend: :ets, algorithm: :token_bucket
  end

  defmodule AtomicFixWindow do
    use Hammer, backend: :atomic, algorithm: :fix_window
  end

  defmodule AtomicLeakyBucket do
    use Hammer, backend: :atomic, algorithm: :leaky_bucket
  end

  defmodule AtomicTokenBucket do
    use Hammer, backend: :atomic, algorithm: :token_bucket
  end

  test "ETS fix window accepts any term as key" do
    start_supervised!(ETSFixWindow)
    scale = :timer.minutes(10)
    limit = 3

    for key <- @keys do
      assert ETSFixWindow.get(key, scale) == 0
      assert {:allow, 1} = ETSFixWindow.hit(key, scale, limit)
      assert ETSFixWindow.inc(key, scale) == 2
      assert ETSFixWindow.set(key, scale, limit) == limit
      assert ETSFixWindow.get(key, scale) == limit
      assert {:deny, _retry_after} = ETSFixWindow.hit(key, scale, limit)
    end
  end

  test "ETS sliding window accepts any term as key" do
    start_supervised!(ETSSlidingWindow)
    scale = :timer.minutes(10)
    limit = 2

    for key <- @keys do
      assert ETSSlidingWindow.get(key, scale) == 0
      assert {:allow, 1} = ETSSlidingWindow.hit(key, scale, limit)
      assert ETSSlidingWindow.get(key, scale) == 1
      assert {:allow, 2} = ETSSlidingWindow.hit(key, scale, limit)
      assert {:deny, _retry_after} = ETSSlidingWindow.hit(key, scale, limit)
    end
  end

  test "ETS leaky bucket accepts any term as key" do
    start_supervised!(ETSLeakyBucket)
    leak_rate = 1
    capacity = 2

    for key <- @keys do
      assert ETSLeakyBucket.get(key, leak_rate) == 0
      assert {:allow, 1} = ETSLeakyBucket.hit(key, leak_rate, capacity, 1)
      assert ETSLeakyBucket.get(key, leak_rate) == 1
      assert {:allow, 2} = ETSLeakyBucket.hit(key, leak_rate, capacity, 1)
      assert {:deny, _retry_after} = ETSLeakyBucket.hit(key, leak_rate, capacity, 1)
    end
  end

  test "ETS token bucket accepts any term as key" do
    start_supervised!(ETSTokenBucket)
    refill_rate = 1
    capacity = 2

    for key <- @keys do
      assert ETSTokenBucket.get(key, refill_rate) == 0
      assert {:allow, 1} = ETSTokenBucket.hit(key, refill_rate, capacity, 1)
      assert ETSTokenBucket.get(key, refill_rate) == 1
      assert {:allow, 0} = ETSTokenBucket.hit(key, refill_rate, capacity, 1)
      assert {:deny, _retry_after} = ETSTokenBucket.hit(key, refill_rate, capacity, 1)
    end
  end

  test "Atomic fix window accepts any term as key" do
    start_supervised!(AtomicFixWindow)
    scale = :timer.minutes(10)
    limit = 3

    for key <- @keys do
      assert AtomicFixWindow.get(key, scale) == 0
      assert {:allow, 1} = AtomicFixWindow.hit(key, scale, limit)
      assert AtomicFixWindow.inc(key, scale) == 2
      assert AtomicFixWindow.set(key, scale, limit) == limit
      assert AtomicFixWindow.get(key, scale) == limit
      assert {:deny, _retry_after} = AtomicFixWindow.hit(key, scale, limit)
    end
  end

  test "Atomic leaky bucket accepts any term as key" do
    start_supervised!(AtomicLeakyBucket)
    leak_rate = 1
    capacity = 2

    for key <- @keys do
      assert AtomicLeakyBucket.get(key, leak_rate) == 0
      assert {:allow, 1} = AtomicLeakyBucket.hit(key, leak_rate, capacity, 1)
      assert AtomicLeakyBucket.get(key, leak_rate) == 1
      assert {:allow, 2} = AtomicLeakyBucket.hit(key, leak_rate, capacity, 1)
      assert {:deny, _retry_after} = AtomicLeakyBucket.hit(key, leak_rate, capacity, 1)
    end
  end

  test "Atomic token bucket accepts any term as key" do
    start_supervised!(AtomicTokenBucket)
    refill_rate = 1
    capacity = 2

    for key <- @keys do
      assert AtomicTokenBucket.get(key, refill_rate) == 0
      assert {:allow, 1} = AtomicTokenBucket.hit(key, refill_rate, capacity, 1)
      assert AtomicTokenBucket.get(key, refill_rate) == 1
      assert {:allow, 0} = AtomicTokenBucket.hit(key, refill_rate, capacity, 1)
      assert {:deny, _retry_after} = AtomicTokenBucket.hit(key, refill_rate, capacity, 1)
    end
  end
end
