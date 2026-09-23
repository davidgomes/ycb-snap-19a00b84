defmodule Paginator.Ecto.Query.FieldOrExpression do
  @moduledoc false

  import Ecto.Query

  def field_or_expr_is_nil(%{column: {_field, expression}}) when is_function(expression, 0) do
    dynamic(is_nil(^expression.()))
  end

  def field_or_expr_is_nil(args) do
    dynamic([{query, args.entity_position}], is_nil(field(query, ^args.column)))
  end

  def field_or_expr_equal(%{column: {_field, expression}, value: value})
      when is_function(expression, 0) do
    dynamic(^expression.() == ^value)
  end

  def field_or_expr_equal(args) do
    dynamic([{query, args.entity_position}], field(query, ^args.column) == ^args.value)
  end

  def field_or_expr_less(%{column: {_field, expression}, value: value})
      when is_function(expression, 0) do
    dynamic(^expression.() < ^value)
  end

  def field_or_expr_less(args) do
    dynamic([{query, args.entity_position}], field(query, ^args.column) < ^args.value)
  end

  def field_or_expr_greater(%{column: {_field, expression}, value: value})
      when is_function(expression, 0) do
    dynamic(^expression.() > ^value)
  end

  def field_or_expr_greater(args) do
    dynamic([{query, args.entity_position}], field(query, ^args.column) > ^args.value)
  end
end
