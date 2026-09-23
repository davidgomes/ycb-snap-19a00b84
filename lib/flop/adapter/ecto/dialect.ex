defmodule Flop.Adapter.Ecto.Dialect do
  @moduledoc false

  # ILIKE is a PostgreSQL extension. Flop falls back to LIKE for Ecto adapters
  # that don't support it. SQLite performs LIKE queries case-insensitively for
  # ASCII only. MySQL does so depending on the column collation. Falling back
  # for an unmeasured adapter would silently make a case-insensitive filter
  # case-sensitive.
  @without_ilike [Ecto.Adapters.MyXQL, Ecto.Adapters.SQLite3]

  # MySQL has neither NULLS FIRST nor NULLS LAST. It sorts NULLs first
  # ascending and last descending, so two of the four directions are plain ASC
  # and DESC, and the other two need `field IS NULL` as an extra sort key.
  @without_nulls_ordering [Ecto.Adapters.MyXQL]

  # Ecto's MyXQL adapter can store arrays in JSON columns, but it cannot build
  # array operations. Flop uses JSON_CONTAINS and JSON_LENGTH instead.
  @without_arrays [Ecto.Adapters.MyXQL]

  @typedoc """
  Feature support of a repo's Ecto adapter, resolved once per query and passed
  to the query builders.
  """
  @type t :: %__MODULE__{
          arrays?: boolean,
          ilike?: boolean,
          nulls_ordering?: boolean,
          asc_nulls: :first | :last
        }

  # Postgres sorts NULLs last when ascending and first when descending.
  # SQLite and MySQL do the opposite. Explicit `*_nulls_first` and
  # `*_nulls_last` directions name the position on every adapter.
  defstruct arrays?: true,
            ilike?: true,
            nulls_ordering?: true,
            asc_nulls: :last

  @nulls_ordering_fallback %{
    asc_nulls_first: {:native, :asc},
    asc_nulls_last: {:emulated, :asc},
    desc_nulls_first: {:emulated, :desc},
    desc_nulls_last: {:native, :desc}
  }

  @doc """
  Returns the dialect for a repo, or the defaults if the repo or its adapter
  are unknown.
  """
  @spec new(module | nil) :: t
  def new(repo) do
    adapter = adapter(repo)

    %__MODULE__{
      arrays?: adapter not in @without_arrays,
      ilike?: adapter not in @without_ilike,
      nulls_ordering?: adapter not in @without_nulls_ordering,
      asc_nulls: asc_nulls(adapter)
    }
  end

  # SQLite treats NULL as smaller than every value. MySQL sorts NULLs first
  # when ascending. Postgres sorts them last.
  defp asc_nulls(Ecto.Adapters.SQLite3), do: :first
  defp asc_nulls(Ecto.Adapters.MyXQL), do: :first
  defp asc_nulls(_adapter), do: :last

  @doc """
  Returns whether NULLs sort before or after other values for an order
  direction on this adapter.

  `:asc` and `:desc` follow the adapter default. The `*_nulls_first` and
  `*_nulls_last` directions use the position in their name, which is also how
  MySQL emulates the directions it cannot write natively.
  """
  @spec nulls_position(t, atom) :: :first | :last
  def nulls_position(%__MODULE__{asc_nulls: asc_nulls}, direction) do
    case direction do
      :asc -> asc_nulls
      :desc -> opposite(asc_nulls)
      :asc_nulls_first -> :first
      :desc_nulls_first -> :first
      :asc_nulls_last -> :last
      :desc_nulls_last -> :last
    end
  end

  defp opposite(:first), do: :last
  defp opposite(:last), do: :first

  @doc """
  Dumps a filter value with the element type of an array field.

  Takes the type of the field, not of the element. Returns the value unchanged
  if it cannot be dumped, or if there is no type, which is the case for a query
  built without a schema.
  """
  @spec dump_array_element(term, term) :: term
  def dump_array_element(value, {:array, element_type}) do
    case Ecto.Type.dump(element_type, value) do
      {:ok, dumped} -> dumped
      :error -> value
    end
  end

  def dump_array_element(value, _ecto_type), do: value

  @doc """
  Returns how to build the `ORDER BY` clause for an order direction.

  - `{:native, direction}` - sort by the field with that direction.
  - `{:emulated, direction}` - sort by `field IS NULL` first, then by the
    field, both with that direction. This replaces `NULLS FIRST` and
    `NULLS LAST` on adapters that don't support them.
  """
  @spec order_direction(t, atom) :: {:native | :emulated, atom}
  def order_direction(%__MODULE__{nulls_ordering?: true}, direction) do
    {:native, direction}
  end

  def order_direction(%__MODULE__{}, direction) do
    Map.get(@nulls_ordering_fallback, direction, {:native, direction})
  end

  defp adapter(repo) when is_atom(repo) and not is_nil(repo) do
    if Code.ensure_loaded?(repo) and
         function_exported?(repo, :__adapter__, 0) do
      repo.__adapter__()
    end
  end

  defp adapter(_repo), do: nil
end
