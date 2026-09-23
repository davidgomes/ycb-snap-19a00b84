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
    filters = build_filters(query, fields, values, cursor_direction)

    where(query, [{q, 0}], ^filters)
  end

  defp build_filters(_query, [], _values, _cursor_direction), do: true

  defp build_filters(query, [{bound_column, order} | next_fields], values, cursor_direction) do
    {position, column} = column_position(query, bound_column)
    value = Map.get(values, bound_column)

    past =
      order
      |> cursor_order(cursor_direction)
      |> past_value(position, column, value)

    case next_fields do
      [] ->
        past

      _ ->
        tied = equal_to_value(position, column, value)
        next_filters = build_filters(query, next_fields, values, cursor_direction)

        past_or_tied(past, tied, next_filters)
    end
  end

  # Records before the cursor are the ones after it once the sort order is reversed.
  defp cursor_order(order, :after), do: normalize_order(order)
  defp cursor_order(order, :before), do: order |> normalize_order() |> reverse_direction()

  # PostgreSQL sorts NULLs last in ascending order and first in descending order.
  defp normalize_order(:asc), do: :asc_nulls_last
  defp normalize_order(:desc), do: :desc_nulls_first

  defp normalize_order(order)
       when order in [:asc_nulls_first, :asc_nulls_last, :desc_nulls_first, :desc_nulls_last],
       do: order

  defp normalize_order(order),
    do:
      raise(
        "Invalid sorting value :#{order}, please use either :asc, :asc_nulls_first, " <>
          ":asc_nulls_last, :desc, :desc_nulls_first or :desc_nulls_last"
      )

  # Matches the records sorting strictly after `value` in the given order.
  defp past_value(:asc_nulls_last, _position, _column, nil), do: false
  defp past_value(:desc_nulls_last, _position, _column, nil), do: false

  defp past_value(nulls_first, position, column, nil)
       when nulls_first in [:asc_nulls_first, :desc_nulls_first],
       do: dynamic([{q, position}], not is_nil(field(q, ^column)))

  defp past_value(:asc_nulls_first, position, column, value),
    do: dynamic([{q, position}], field(q, ^column) > ^value)

  defp past_value(:asc_nulls_last, position, column, value),
    do: dynamic([{q, position}], field(q, ^column) > ^value or is_nil(field(q, ^column)))

  defp past_value(:desc_nulls_first, position, column, value),
    do: dynamic([{q, position}], field(q, ^column) < ^value)

  defp past_value(:desc_nulls_last, position, column, value),
    do: dynamic([{q, position}], field(q, ^column) < ^value or is_nil(field(q, ^column)))

  defp equal_to_value(position, column, nil),
    do: dynamic([{q, position}], is_nil(field(q, ^column)))

  defp equal_to_value(position, column, value),
    do: dynamic([{q, position}], field(q, ^column) == ^value)

  defp past_or_tied(false, tied, next_filters), do: dynamic(^tied and ^next_filters)
  defp past_or_tied(past, tied, next_filters), do: dynamic(^past or (^tied and ^next_filters))

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
            | expr: Enum.map(expr, fn {direction, ast} -> {reverse_direction(direction), ast} end)
          }
        end
    end)
  end

  defp reverse_direction(:asc), do: :desc
  defp reverse_direction(:asc_nulls_last), do: :desc_nulls_first
  defp reverse_direction(:asc_nulls_first), do: :desc_nulls_last
  defp reverse_direction(:desc), do: :asc
  defp reverse_direction(:desc_nulls_first), do: :asc_nulls_last
  defp reverse_direction(:desc_nulls_last), do: :asc_nulls_first
end
