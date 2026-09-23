defmodule Paginator.Ecto.Query.FieldOrExpression do
  @moduledoc false

  import Ecto.Query

  def field_or_expr(%{column: {_name, handler}}) when is_function(handler, 0) do
    handler.()
  end

  def field_or_expr(args) do
    dynamic([{query, args.entity_position}], field(query, ^args.column))
  end
end
