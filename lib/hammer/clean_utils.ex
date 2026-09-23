defmodule Hammer.CleanUtils do
  @moduledoc false

  require Logger

  @spec validate_before_clean!(term()) :: Hammer.before_clean() | nil
  def validate_before_clean!(nil), do: nil
  def validate_before_clean!(fun) when is_function(fun, 2), do: fun

  def validate_before_clean!({module, fun, args} = mfa)
      when is_atom(module) and is_atom(fun) and is_list(args),
      do: mfa

  def validate_before_clean!(other) do
    raise ArgumentError,
          "expected :before_clean to be a 2-arity function or a {module, function, args} tuple, got: #{inspect(other)}"
  end

  @spec run_before_clean(Hammer.before_clean(), atom(), atom(), [map()]) :: :ok
  def run_before_clean(before_clean, table, algorithm, entries) do
    invoke(before_clean, algorithm, entries)
    :ok
  catch
    kind, reason ->
      Logger.warning(
        "#{inspect(table)} before_clean callback failed, expired entries will still be deleted:\n" <>
          Exception.format(kind, reason, __STACKTRACE__)
      )

      :ok
  end

  defp invoke(fun, algorithm, entries) when is_function(fun, 2), do: fun.(algorithm, entries)

  defp invoke({module, fun, args}, algorithm, entries),
    do: apply(module, fun, [algorithm, entries | args])
end
