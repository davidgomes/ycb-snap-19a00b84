defmodule Paginator.Ecto.Query.FieldOrExpression do
  @moduledoc false

  import Ecto.Query

  alias Ecto.Query.DynamicExpr

  def field_or_expr_is_nil(%{column: %DynamicExpr{} = expr}) do
    dynamic(is_nil(^expr))
  end

  def field_or_expr_is_nil(args) do
    dynamic([{query, args.entity_position}], is_nil(field(query, ^args.column)))
  end

  def field_or_expr_equal(%{column: %DynamicExpr{} = expr, value: value}) do
    dynamic(^expr == ^value)
  end

  def field_or_expr_equal(args) do
    dynamic([{query, args.entity_position}], field(query, ^args.column) == ^args.value)
  end

  def field_or_expr_greater(%{column: %DynamicExpr{} = expr, value: value}) do
    dynamic(^expr > ^value)
  end

  def field_or_expr_greater(args) do
    dynamic([{query, args.entity_position}], field(query, ^args.column) > ^args.value)
  end

  def field_or_expr_less(%{column: %DynamicExpr{} = expr, value: value}) do
    dynamic(^expr < ^value)
  end

  def field_or_expr_less(args) do
    dynamic([{query, args.entity_position}], field(query, ^args.column) < ^args.value)
  end
end
