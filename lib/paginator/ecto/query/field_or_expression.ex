defmodule Paginator.Ecto.Query.FieldOrExpression do
  @moduledoc false

  import Ecto.Query

  def field_or_expr_is_nil(%{column: {_, handler}}) when is_function(handler, 0) do
    dynamic(is_nil(^handler.()))
  end

  def field_or_expr_is_nil(args) do
    dynamic([{query, args.entity_position}], is_nil(field(query, ^args.column)))
  end

  def field_or_expr_equal(%{column: {_, handler}} = args) when is_function(handler, 0) do
    dynamic(^handler.() == ^args.value)
  end

  def field_or_expr_equal(args) do
    dynamic([{query, args.entity_position}], field(query, ^args.column) == ^args.value)
  end

  def field_or_expr_less(%{column: {_, handler}} = args) when is_function(handler, 0) do
    dynamic(^handler.() < ^args.value)
  end

  def field_or_expr_less(args) do
    dynamic([{query, args.entity_position}], field(query, ^args.column) < ^args.value)
  end

  def field_or_expr_greater(%{column: {_, handler}} = args) when is_function(handler, 0) do
    dynamic(^handler.() > ^args.value)
  end

  def field_or_expr_greater(args) do
    dynamic([{query, args.entity_position}], field(query, ^args.column) > ^args.value)
  end
end
