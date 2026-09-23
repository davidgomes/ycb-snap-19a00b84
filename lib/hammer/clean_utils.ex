defmodule Hammer.CleanUtils do
  @moduledoc false

  require Logger

  @type entry :: %{key: term(), value: non_neg_integer(), expired_at: integer()}
  @type before_clean :: (atom(), [entry()] -> any()) | {module(), atom(), list()}

  # Failures are logged rather than propagated so the caller still deletes the
  # expired entries; otherwise a broken callback would let the table grow forever.
  @spec invoke_before_clean(before_clean(), atom(), [entry()]) :: :ok
  def invoke_before_clean(callback, algorithm, entries) do
    case callback do
      {mod, fun, extra_args} -> apply(mod, fun, [algorithm, entries | extra_args])
      fun when is_function(fun, 2) -> fun.(algorithm, entries)
    end

    :ok
  rescue
    e ->
      Logger.warning(
        "before_clean callback raised: #{Exception.format(:error, e, __STACKTRACE__)}"
      )
  catch
    kind, reason ->
      Logger.warning("before_clean callback failed: #{inspect({kind, reason})}")
  end

  @spec delete_expired(atom(), list()) :: :ok
  def delete_expired(table, expired) do
    Enum.each(expired, &:ets.delete_object(table, &1))
  end
end
