defmodule Paginator.Ecto.Query.FieldOrExpression do
  @moduledoc false

  import Ecto.Query

  @doc """
  Builds the term that a pagination filter compares the cursor value against.

  A cursor field is normally a column, in which case the term is that column
  read from the binding the field points at.

  A cursor field can also be an expression, written as
  `{key, fn -> dynamic(...) end}`. The supplied function is then used as the
  term, which lets a query paginate on a value it computes rather than on a
  column of the schema. `key` is what the value is stored under in the cursor.
  """
  @spec build!(%{entity_position: integer(), column: term()}) :: Ecto.Query.dynamic()
  def build!(%{column: {_key, expression}}) when is_function(expression, 0) do
    expression.()
  end

  def build!(%{entity_position: entity_position, column: column}) when is_atom(column) do
    dynamic([{query, entity_position}], field(query, ^column))
  end
end
