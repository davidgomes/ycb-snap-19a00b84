defmodule Paginator.Ecto.Query.FieldOrExpression do
  @moduledoc false

  import Ecto.Query

  alias Ecto.Query.DynamicExpr

  # Fields are compared through `field/2` so Ecto can type the cursor value
  # from the schema. Expressions have no schema type, so their cursor value is
  # sent untyped and the database infers it from the expression.

  def null(%{column: %DynamicExpr{} = expression}) do
    dynamic(is_nil(^expression))
  end

  def null(args) do
    dynamic([{query, args.entity_position}], is_nil(field(query, ^args.column)))
  end

  def equal(%{column: %DynamicExpr{} = expression, value: value}) do
    dynamic(^expression == ^value)
  end

  def equal(args) do
    dynamic([{query, args.entity_position}], field(query, ^args.column) == ^args.value)
  end

  def greater(%{column: %DynamicExpr{} = expression, value: value}) do
    dynamic(^expression > ^value)
  end

  def greater(args) do
    dynamic([{query, args.entity_position}], field(query, ^args.column) > ^args.value)
  end

  def less(%{column: %DynamicExpr{} = expression, value: value}) do
    dynamic(^expression < ^value)
  end

  def less(args) do
    dynamic([{query, args.entity_position}], field(query, ^args.column) < ^args.value)
  end
end
