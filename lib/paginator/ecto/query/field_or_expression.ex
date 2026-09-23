defmodule Paginator.Ecto.Query.FieldOrExpression do
  @moduledoc false

  import Ecto.Query

  # Expressions are resolved against the query's own bindings, so the
  # entity position is only relevant for plain columns.

  def field_or_expr_is_nil(%{column: {_name, expression}}) when is_function(expression, 0) do
    dynamic(is_nil(^expression.()))
  end

  def field_or_expr_is_nil(args) do
    dynamic([{query, args.entity_position}], is_nil(field(query, ^args.column)))
  end

  def field_or_expr_equal(%{column: {_name, expression}, value: value})
      when is_function(expression, 0) do
    dynamic(^expression.() == ^value)
  end

  def field_or_expr_equal(args) do
    dynamic([{query, args.entity_position}], field(query, ^args.column) == ^args.value)
  end

  def field_or_expr_less(%{column: {_name, expression}, value: value})
      when is_function(expression, 0) do
    dynamic(^expression.() < ^value)
  end

  def field_or_expr_less(args) do
    dynamic([{query, args.entity_position}], field(query, ^args.column) < ^args.value)
  end

  def field_or_expr_greater(%{column: {_name, expression}, value: value})
      when is_function(expression, 0) do
    dynamic(^expression.() > ^value)
  end

  def field_or_expr_greater(args) do
    dynamic([{query, args.entity_position}], field(query, ^args.column) > ^args.value)
  end
end
