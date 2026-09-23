defmodule Hammer.TermKeysTest do
  use ExUnit.Case, async: true

  @keys [
    :user_123,
    123,
    {"user", 123},
    ["user", 123],
    %{user_id: 123, action: :login}
  ]

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

  describe "fix window" do
    test "ETS backend accepts any term as key" do
      start_supervised!(ETSFixWindow)
      assert_fix_window_term_keys(ETSFixWindow)
    end

    test "Atomic backend accepts any term as key" do
      start_supervised!(AtomicFixWindow)
      assert_fix_window_term_keys(AtomicFixWindow)
    end
  end

  describe "sliding window" do
    test "ETS backend accepts any term as key" do
      start_supervised!(ETSSlidingWindow)

      scale = :timer.minutes(10)
      limit = 2

      for key <- @keys do
        assert ETSSlidingWindow.get(key, scale) == 0
        assert {:allow, 1} = ETSSlidingWindow.hit(key, scale, limit)
        assert {:allow, 2} = ETSSlidingWindow.hit(key, scale, limit)
        assert {:deny, _retry_after} = ETSSlidingWindow.hit(key, scale, limit)
      end
    end
  end

  describe "leaky bucket" do
    test "ETS backend accepts any term as key" do
      start_supervised!(ETSLeakyBucket)
      assert_leaky_bucket_term_keys(ETSLeakyBucket)
    end

    test "Atomic backend accepts any term as key" do
      start_supervised!(AtomicLeakyBucket)
      assert_leaky_bucket_term_keys(AtomicLeakyBucket)
    end
  end

  describe "token bucket" do
    test "ETS backend accepts any term as key" do
      start_supervised!(ETSTokenBucket)
      assert_token_bucket_term_keys(ETSTokenBucket)
    end

    test "Atomic backend accepts any term as key" do
      start_supervised!(AtomicTokenBucket)
      assert_token_bucket_term_keys(AtomicTokenBucket)
    end
  end

  defp assert_fix_window_term_keys(rate_limit) do
    scale = :timer.minutes(10)
    limit = 2

    for key <- @keys do
      assert rate_limit.get(key, scale) == 0
      assert {:allow, 1} = rate_limit.hit(key, scale, limit)
      assert {:allow, 2} = rate_limit.hit(key, scale, limit)
      assert {:deny, _retry_after} = rate_limit.hit(key, scale, limit)
      assert rate_limit.get(key, scale) == 3
      assert rate_limit.set(key, scale, 0) == 0
      assert rate_limit.inc(key, scale) == 1
    end
  end

  defp assert_leaky_bucket_term_keys(rate_limit) do
    leak_rate = 1
    capacity = 2

    for key <- @keys do
      assert rate_limit.get(key, leak_rate) == 0
      assert {:allow, 1} = rate_limit.hit(key, leak_rate, capacity)
      assert {:allow, 2} = rate_limit.hit(key, leak_rate, capacity)
      assert {:deny, _retry_after} = rate_limit.hit(key, leak_rate, capacity)
      assert rate_limit.get(key, leak_rate) == 2
    end
  end

  defp assert_token_bucket_term_keys(rate_limit) do
    refill_rate = 1
    capacity = 2

    for key <- @keys do
      assert {:allow, 1} = rate_limit.hit(key, refill_rate, capacity)
      assert rate_limit.get(key, refill_rate) == 1
      assert {:allow, 0} = rate_limit.hit(key, refill_rate, capacity)
      assert {:deny, _retry_after} = rate_limit.hit(key, refill_rate, capacity)
    end
  end
end
