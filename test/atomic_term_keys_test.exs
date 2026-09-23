defmodule AtomicTermKeysTest do
  use ExUnit.Case, async: true

  defmodule TestAtomicRateLimit do
    use Hammer, backend: :atomic
  end

  defmodule TestAtomicLeakyBucket do
    use Hammer, backend: :atomic, algorithm: :leaky_bucket
  end

  defmodule TestAtomicTokenBucket do
    use Hammer, backend: :atomic, algorithm: :token_bucket
  end

  setup do
    start_supervised!({TestAtomicRateLimit, clean_period: :timer.minutes(10)})
    start_supervised!({TestAtomicLeakyBucket, clean_period: :timer.minutes(10)})
    start_supervised!({TestAtomicTokenBucket, clean_period: :timer.minutes(10)})
    :ok
  end

  for {name, key} <- [
        atom: :atom_key,
        tuple: {"user", 456},
        integer: 789,
        list: [:atomic, :key],
        map: %{user_id: 456, action: :login}
      ] do
    test "#{name} keys work with the atomic fixed window backend" do
      key = unquote(Macro.escape(key))

      assert {:allow, 1} = TestAtomicRateLimit.hit(key, 1000, 5)
      assert {:allow, 2} = TestAtomicRateLimit.hit(key, 1000, 5)
      assert TestAtomicRateLimit.get(key, 1000) == 2
      assert TestAtomicRateLimit.inc(key, 1000) == 3
      assert TestAtomicRateLimit.set(key, 1000, 1) == 1
      assert TestAtomicRateLimit.get(key, 1000) == 1
    end

    test "#{name} keys work with the atomic leaky bucket backend" do
      key = unquote(Macro.escape(key))

      assert {:allow, 1} = TestAtomicLeakyBucket.hit(key, 10, 10, 1)
      assert {:allow, 2} = TestAtomicLeakyBucket.hit(key, 10, 10, 1)
      assert TestAtomicLeakyBucket.get(key, 1000) == 2
    end

    test "#{name} keys work with the atomic token bucket backend" do
      key = unquote(Macro.escape(key))

      assert {:allow, 9} = TestAtomicTokenBucket.hit(key, 10, 10, 1)
      assert {:allow, 8} = TestAtomicTokenBucket.hit(key, 10, 10, 1)
      assert TestAtomicTokenBucket.get(key, 1000) == 8
    end
  end
end
