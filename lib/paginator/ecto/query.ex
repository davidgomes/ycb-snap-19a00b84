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

  @nulls_orders [:asc_nulls_first, :asc_nulls_last, :desc_nulls_first, :desc_nulls_last]
  @sort_orders [:asc, :desc | @nulls_orders]

  # Paginating `:before` a cursor is the same as paginating `:after` it in the
  # reversed sort order, so every filter is expressed as an `:after` filter.
  defp after_order(order, :after), do: order
  defp after_order(order, :before), do: reverse_sort_order(order)

  defp reverse_sort_order(:asc), do: :desc
  defp reverse_sort_order(:desc), do: :asc
  defp reverse_sort_order(:asc_nulls_first), do: :desc_nulls_last
  defp reverse_sort_order(:asc_nulls_last), do: :desc_nulls_first
  defp reverse_sort_order(:desc_nulls_first), do: :asc_nulls_last
  defp reverse_sort_order(:desc_nulls_last), do: :asc_nulls_first

  defp validate_order!(order) when order in @sort_orders, do: order

  defp validate_order!(order),
    do:
      raise(
        "Invalid sorting value :#{order}, please use one of " <>
          Enum.map_join(@sort_orders, ", ", &":#{&1}")
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
        {column, Map.get(values, column), after_order(validate_order!(order), cursor_direction)}
      end)
      # Plain :asc/:desc columns ignore nil cursor values; the explicit nulls
      # orders know where NULLs sort and filter on them.
      |> Enum.reject(fn {_column, value, order} -> is_nil(value) and order in [:asc, :desc] end)

    dynamic_sorts =
      case sorts do
        [] -> true
        sorts -> build_filters(query, sorts)
      end

    where(query, [{q, 0}], ^dynamic_sorts)
  end

  # Builds the lexicographic "strictly after" condition for the given sorts,
  # where `next` is the condition for the remaining sorts (`false` once none are
  # left, as a row equal on every column is not after the cursor).
  defp build_filters(_query, []), do: false

  defp build_filters(query, [{bound_column, value, order} | rest]) do
    {position, column} = column_position(query, bound_column)
    next = build_filters(query, rest)

    after_filter(position, column, value, order, next)
  end

  defp after_filter(position, column, nil, order, next)
       when order in [:asc_nulls_last, :desc_nulls_last] do
    if next == false do
      false
    else
      dynamic([{q, position}], is_nil(field(q, ^column)) and ^next)
    end
  end

  defp after_filter(position, column, nil, order, next)
       when order in [:asc_nulls_first, :desc_nulls_first] do
    if next == false do
      dynamic([{q, position}], not is_nil(field(q, ^column)))
    else
      dynamic(
        [{q, position}],
        not is_nil(field(q, ^column)) or (is_nil(field(q, ^column)) and ^next)
      )
    end
  end

  defp after_filter(position, column, value, order, next) do
    dynamic =
      if order in [:asc, :asc_nulls_first, :asc_nulls_last] do
        dynamic([{q, position}], field(q, ^column) > ^value)
      else
        dynamic([{q, position}], field(q, ^column) < ^value)
      end

    dynamic =
      if order in [:asc_nulls_last, :desc_nulls_last] do
        dynamic([{q, position}], ^dynamic or is_nil(field(q, ^column)))
      else
        dynamic
      end

    if next == false do
      dynamic
    else
      dynamic([{q, position}], ^dynamic or (field(q, ^column) == ^value and ^next))
    end
  end

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
            | expr: Enum.map(expr, fn {order, ast} -> {reverse_sort_order(order), ast} end)
          }
        end
    end)
  end
end
