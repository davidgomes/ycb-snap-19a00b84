defmodule Hammer.CleanUtils do
  @moduledoc false

  require Logger

  @typedoc """
  A callback invoked with the algorithm name and the list of expired entries
  right before they are removed from the table.

  Either a 2-arity function, or a `{module, function, extra_args}` tuple which is
  called as `apply(module, function, [algorithm, entries | extra_args])`.
  """
  @type before_clean :: (atom(), [map()] -> any()) | {module(), atom(), list()}

  @spec validate_before_clean!(term()) :: before_clean() | nil
  def validate_before_clean!(nil), do: nil
  def validate_before_clean!(fun) when is_function(fun, 2), do: fun

  def validate_before_clean!({module, function, args} = mfa)
      when is_atom(module) and is_atom(function) and is_list(args),
      do: mfa

  def validate_before_clean!(other) do
    raise ArgumentError,
          "expected :before_clean to be a 2-arity function or a {module, function, args} tuple, got: #{inspect(other)}"
  end

  @spec algorithm_name(module()) :: atom()
  def algorithm_name(Hammer.ETS.FixWindow), do: :fix_window
  def algorithm_name(Hammer.ETS.SlidingWindow), do: :sliding_window
  def algorithm_name(Hammer.ETS.LeakyBucket), do: :leaky_bucket
  def algorithm_name(Hammer.ETS.TokenBucket), do: :token_bucket
  def algorithm_name(Hammer.Atomic.FixWindow), do: :fix_window
  def algorithm_name(Hammer.Atomic.LeakyBucket), do: :leaky_bucket
  def algorithm_name(Hammer.Atomic.TokenBucket), do: :token_bucket
  def algorithm_name(module), do: module

  @doc """
  Invokes the `before_clean` callback, logging (instead of propagating) any failure
  so that expired entries are still removed and the cleaning process keeps running.
  """
  @spec invoke_before_clean(before_clean(), atom(), [map()]) :: :ok
  def invoke_before_clean(_callback, _algorithm, []), do: :ok

  def invoke_before_clean(callback, algorithm, entries) do
    call(callback, algorithm, entries)
    :ok
  catch
    kind, reason ->
      Logger.warning(
        "Hammer :before_clean callback failed for #{inspect(algorithm)}: " <>
          Exception.format(kind, reason, __STACKTRACE__)
      )

      :ok
  end

  defp call(fun, algorithm, entries) when is_function(fun, 2), do: fun.(algorithm, entries)

  defp call({module, function, args}, algorithm, entries),
    do: apply(module, function, [algorithm, entries | args])
end
