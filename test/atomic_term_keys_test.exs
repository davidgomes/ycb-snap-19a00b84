defmodule Hammer.AtomicTermKeysTest do
  use ExUnit.Case, async: true

  defmodule RateLimit do
    use Hammer, backend: :atomic
  end

  defmodule RateLimitLeakyBucket do
    use Hammer, backend: :atomic, algorithm: :leaky_bucket
  end

  defmodule RateLimitTokenBucket do
    use Hammer, backend: :atomic, algorithm: :token_bucket
  end

  setup do
    start_supervised!(RateLimit)
    start_supervised!(RateLimitLeakyBucket)
    start_supervised!(RateLimitTokenBucket)
    :ok
  end

  @test_keys [
    :atom_key,
    {:tuple, "key", 123},
    12_345,
    ["list", :key, 1],
    %{map: "key", id: 42},
    "string_key"
  ]

  describe "all Atomic algorithms support various term key types" do
    test "fix window supports term keys" do
      for key <- @test_keys do
        assert {:allow, 1} = RateLimit.hit(key, 1000, 10)
        assert RateLimit.get(key, 1000) == 1
        assert RateLimit.inc(key, 1000) == 2
      end
    end

    test "leaky bucket supports term keys" do
      for key <- @test_keys do
        assert {:allow, 1} = RateLimitLeakyBucket.hit(key, 10, 10, 1)
        assert RateLimitLeakyBucket.get(key, 10) == 1
      end
    end

    test "token bucket supports term keys" do
      for key <- @test_keys do
        assert {:allow, 9} = RateLimitTokenBucket.hit(key, 10, 10, 1)
        assert RateLimitTokenBucket.get(key, 10) == 9
      end
    end
  end
end
