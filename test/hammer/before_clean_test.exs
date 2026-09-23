defmodule Hammer.BeforeCleanTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  defmodule EtsFixWindow do
    use Hammer, backend: :ets
  end

  defmodule EtsSlidingWindow do
    use Hammer, backend: :ets, algorithm: :sliding_window
  end

  defmodule EtsTokenBucket do
    use Hammer, backend: :ets, algorithm: :token_bucket
  end

  defmodule EtsLeakyBucket do
    use Hammer, backend: :ets, algorithm: :leaky_bucket
  end

  defmodule AtomicFixWindow do
    use Hammer, backend: :atomic
  end

  defmodule AtomicTokenBucket do
    use Hammer, backend: :atomic, algorithm: :token_bucket
  end

  defmodule AtomicLeakyBucket do
    use Hammer, backend: :atomic, algorithm: :leaky_bucket
  end

  def forward(algorithm, entries, pid), do: send(pid, {:before_clean, algorithm, entries})

  defp callback do
    test_pid = self()
    fn algorithm, entries -> send(test_pid, {:before_clean, algorithm, entries}) end
  end

  defp wait_for_empty(table, attempts \\ 250)
  defp wait_for_empty(_table, 0), do: flunk("table was not cleaned")

  defp wait_for_empty(table, attempts) do
    if :ets.tab2list(table) != [] do
      Process.sleep(20)
      wait_for_empty(table, attempts - 1)
    end
  end

  describe "ets backend" do
    test "fix window" do
      start_supervised!({EtsFixWindow, clean_period: 50, before_clean: callback()})
      assert {:allow, 2} = EtsFixWindow.hit("key", 50, 10, 2)

      assert_receive {:before_clean, :fix_window, [%{key: "key", value: 2, expired_at: at}]},
                     2000

      assert is_integer(at)
      wait_for_empty(EtsFixWindow)
    end

    test "sliding window" do
      start_supervised!({EtsSlidingWindow, clean_period: 50, before_clean: callback()})
      assert {:allow, 1} = EtsSlidingWindow.hit("key", 1, 10)

      assert_receive {:before_clean, :sliding_window, [%{key: "key", value: 1}]}, 2000
      wait_for_empty(EtsSlidingWindow)
    end

    test "token bucket" do
      start_supervised!(
        {EtsTokenBucket, clean_period: 50, key_older_than: 1000, before_clean: callback()}
      )

      assert {:allow, 9} = EtsTokenBucket.hit("key", 1, 10, 1)

      assert_receive {:before_clean, :token_bucket, [%{key: "key", value: 9}]}, 5000
      wait_for_empty(EtsTokenBucket)
    end

    test "leaky bucket with MFA callback" do
      start_supervised!(
        {EtsLeakyBucket,
         clean_period: 50, key_older_than: 1000, before_clean: {__MODULE__, :forward, [self()]}}
      )

      assert {:allow, 1} = EtsLeakyBucket.hit("key", 1, 10, 1)

      assert_receive {:before_clean, :leaky_bucket, [%{key: "key", value: 1}]}, 5000
      wait_for_empty(EtsLeakyBucket)
    end

    test "entries are still deleted when the callback raises" do
      log =
        capture_log(fn ->
          start_supervised!(
            {EtsFixWindow, clean_period: 50, before_clean: fn _, _ -> raise "boom" end}
          )

          assert {:allow, 1} = EtsFixWindow.hit("key", 50, 10)
          wait_for_empty(EtsFixWindow)
          Process.sleep(50)
        end)

      assert log =~ "before_clean callback raised"
    end
  end

  describe "atomic backend" do
    test "fix window" do
      start_supervised!(
        {AtomicFixWindow, clean_period: 50, key_older_than: 10, before_clean: callback()}
      )

      assert {:allow, 3} = AtomicFixWindow.hit("key", 50, 10, 3)

      assert_receive {:before_clean, :fix_window, [%{key: "key", value: 3}]}, 2000
      wait_for_empty(AtomicFixWindow)
    end

    test "token bucket" do
      start_supervised!(
        {AtomicTokenBucket, clean_period: 50, key_older_than: 1000, before_clean: callback()}
      )

      assert {:allow, 9} = AtomicTokenBucket.hit("key", 1, 10, 1)

      assert_receive {:before_clean, :token_bucket, [%{key: "key", value: 9}]}, 5000
      wait_for_empty(AtomicTokenBucket)
    end

    test "leaky bucket" do
      start_supervised!(
        {AtomicLeakyBucket, clean_period: 50, key_older_than: 1000, before_clean: callback()}
      )

      assert {:allow, 1} = AtomicLeakyBucket.hit("key", 1, 10, 1)

      assert_receive {:before_clean, :leaky_bucket, [%{key: "key", value: 1}]}, 5000
      wait_for_empty(AtomicLeakyBucket)
    end
  end
end
