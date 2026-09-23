defmodule Paginator.Ecto.Query do
  @moduledoc false

  import Ecto.Query

  alias Paginator.Config

  def paginate(queryable, config \\ [])

  def paginate(queryable, %Config{} = config) do
    queryable
    |> maybe_where(config)
    |> limit(^query_limit(config))
  end

  def paginate(queryable, opts) do
    config = Config.new(opts)
    paginate(queryable, config)
  end

  @null_aware_orders [:asc_nulls_first, :asc_nulls_last, :desc_nulls_first, :desc_nulls_last]
  @orders [:asc, :desc | @null_aware_orders]

  defp effective_order(order, :after), do: order
  defp effective_order(order, :before), do: reverse_order(order)

  defp reverse_order(:asc), do: :desc
  defp reverse_order(:desc), do: :asc
  defp reverse_order(:asc_nulls_first), do: :desc_nulls_last
  defp reverse_order(:asc_nulls_last), do: :desc_nulls_first
  defp reverse_order(:desc_nulls_first), do: :asc_nulls_last
  defp reverse_order(:desc_nulls_last), do: :asc_nulls_first

  defp validate_order!(order) when order in @orders, do: order

  defp validate_order!(order),
    do:
      raise(
        "Invalid sorting value :#{order}, please use one of " <>
          Enum.map_join(@orders, ", ", &":#{&1}")
      )

  # This clause is responsible for transforming legacy list cursors into map cursors
  defp filter_values(query, fields, values, cursor_direction) when is_list(values) do
    new_values =
      fields
      |> Keyword.keys()
      |> Enum.zip(values)
      |> Map.new()

    filter_values(query, fields, new_values, cursor_direction)
  end

  defp filter_values(query, fields, values, cursor_direction) when is_map(values) do
    sorts =
      fields
      |> Enum.map(fn {column, order} ->
        {column, validate_order!(order), Map.get(values, column)}
      end)
      |> Enum.reject(fn {_column, order, value} -> is_nil(value) and order in [:asc, :desc] end)

    dynamic_sorts =
      sorts
      |> Enum.with_index()
      |> Enum.reduce(true, fn {{bound_column, order, value}, i}, dynamic_sorts ->
        {position, column} = column_position(query, bound_column)

        dynamic =
          strictly_after(position, column, effective_order(order, cursor_direction), value)

        dynamic =
          sorts
          |> Enum.take(i)
          |> Enum.reduce(dynamic, fn {prev_column, _order, prev_value}, dynamic ->
            {position, prev_column} = column_position(query, prev_column)
            equals = equal_to(position, prev_column, prev_value)
            dynamic([{q, position}], ^equals and ^dynamic)
          end)

        if i == 0 do
          dynamic([{q, position}], ^dynamic and ^dynamic_sorts)
        else
          dynamic([{q, position}], ^dynamic or ^dynamic_sorts)
        end
      end)

    where(query, [{q, 0}], ^dynamic_sorts)
  end

  defp equal_to(position, column, nil), do: dynamic([{q, position}], is_nil(field(q, ^column)))
  defp equal_to(position, column, value), do: dynamic([{q, position}], field(q, ^column) == ^value)

  defp strictly_after(position, column, order, value) when order in [:asc, :asc_nulls_first] do
    if is_nil(value),
      do: dynamic([{q, position}], not is_nil(field(q, ^column))),
      else: dynamic([{q, position}], field(q, ^column) > ^value)
  end

  defp strictly_after(position, column, order, value) when order in [:desc, :desc_nulls_first] do
    if is_nil(value),
      do: dynamic([{q, position}], not is_nil(field(q, ^column))),
      else: dynamic([{q, position}], field(q, ^column) < ^value)
  end

  defp strictly_after(_position, _column, _order, nil), do: false

  defp strictly_after(position, column, :asc_nulls_last, value),
    do: dynamic([{q, position}], field(q, ^column) > ^value or is_nil(field(q, ^column)))

  defp strictly_after(position, column, :desc_nulls_last, value),
    do: dynamic([{q, position}], field(q, ^column) < ^value or is_nil(field(q, ^column)))

  defp maybe_where(query, %Config{
         after: nil,
         before: nil
       }) do
    query
  end

  defp maybe_where(query, %Config{
         after_values: after_values,
         before: nil,
         cursor_fields: cursor_fields
       }) do
    query
    |> filter_values(cursor_fields, after_values, :after)
  end

  defp maybe_where(query, %Config{
         after: nil,
         before_values: before_values,
         cursor_fields: cursor_fields
       }) do
    query
    |> filter_values(cursor_fields, before_values, :before)
    |> reverse_order_bys()
  end

  defp maybe_where(query, %Config{
         after_values: after_values,
         before_values: before_values,
         cursor_fields: cursor_fields
       }) do
    query
    |> filter_values(cursor_fields, after_values, :after)
    |> filter_values(cursor_fields, before_values, :before)
  end

  # Lookup position of binding in query aliases
  defp column_position(query, {binding_name, column}) do
    case Map.fetch(query.aliases, binding_name) do
      {:ok, position} ->
        {position, column}

      _ ->
        raise(
          ArgumentError,
          "Could not find binding `#{binding_name}` in query aliases: #{inspect(query.aliases)}"
        )
    end
  end

  # Without named binding we assume position of binding is 0
  defp column_position(_query, column), do: {0, column}

  #  In order to return the correct pagination cursors, we need to fetch one more
  # # record than we actually want to return.
  defp query_limit(%Config{limit: limit}) do
    limit + 1
  end

  # This code was taken from https://github.com/elixir-ecto/ecto/blob/v2.1.4/lib/ecto/query.ex#L1212-L1226
  defp reverse_order_bys(query) do
    update_in(query.order_bys, fn
      [] ->
        []

      order_bys ->
        for %{expr: expr} = order_by <- order_bys do
          %{
            order_by
            | expr:
                Enum.map(expr, fn
                  {direction, ast} -> {reverse_order(direction), ast}
                end)
          }
        end
    end)
  end
end
