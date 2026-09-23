defmodule TermKeysTest do
  use ExUnit.Case, async: true

  defmodule TestRateLimit do
    use Hammer, backend: :ets
  end

  defmodule TestSlidingWindow do
    use Hammer, backend: :ets, algorithm: :sliding_window
  end

  defmodule TestLeakyBucket do
    use Hammer, backend: :ets, algorithm: :leaky_bucket
  end

  defmodule TestTokenBucket do
    use Hammer, backend: :ets, algorithm: :token_bucket
  end

  setup do
    start_supervised!({TestRateLimit, clean_period: :timer.minutes(10)})
    start_supervised!({TestSlidingWindow, clean_period: :timer.minutes(10)})
    start_supervised!({TestLeakyBucket, clean_period: :timer.minutes(10)})
    start_supervised!({TestTokenBucket, clean_period: :timer.minutes(10)})
    :ok
  end

  for {name, key} <- [
        string: "string_key",
        atom: :atom_key,
        tuple: {"user", 123},
        integer: 12_345,
        list: [1, 2, 3],
        map: %{user_id: 123, action: :login}
      ] do
    test "#{name} keys work with the ETS fixed window backend" do
      key = unquote(Macro.escape(key))

      assert {:allow, 1} = TestRateLimit.hit(key, 1000, 5)
      assert {:allow, 2} = TestRateLimit.hit(key, 1000, 5)
      assert TestRateLimit.get(key, 1000) == 2
      assert TestRateLimit.inc(key, 1000) == 3
      assert TestRateLimit.set(key, 1000, 1) == 1
      assert TestRateLimit.get(key, 1000) == 1
    end

    test "#{name} keys work with the ETS sliding window backend" do
      key = unquote(Macro.escape(key))

      assert {:allow, 1} = TestSlidingWindow.hit(key, :timer.seconds(10), 5)
      assert {:allow, 2} = TestSlidingWindow.hit(key, :timer.seconds(10), 5)
      assert TestSlidingWindow.get(key, :timer.seconds(10)) == 2
    end

    test "#{name} keys work with the ETS leaky bucket backend" do
      key = unquote(Macro.escape(key))

      assert {:allow, 1} = TestLeakyBucket.hit(key, 10, 10, 1)
      assert {:allow, 2} = TestLeakyBucket.hit(key, 10, 10, 1)
      assert TestLeakyBucket.get(key, 1000) == 2
    end

    test "#{name} keys work with the ETS token bucket backend" do
      key = unquote(Macro.escape(key))

      assert {:allow, 9} = TestTokenBucket.hit(key, 10, 10, 1)
      assert {:allow, 8} = TestTokenBucket.hit(key, 10, 10, 1)
      assert TestTokenBucket.get(key, 1000) == 8
    end
  end
end
