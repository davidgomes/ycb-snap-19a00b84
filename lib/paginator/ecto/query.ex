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

  @sort_orders [
    :asc,
    :asc_nulls_first,
    :asc_nulls_last,
    :desc,
    :desc_nulls_first,
    :desc_nulls_last
  ]

  # `:asc` and `:desc` follow the PostgreSQL defaults for NULL placement.
  defp normalize_sort_order(:asc), do: :asc_nulls_last
  defp normalize_sort_order(:desc), do: :desc_nulls_first
  defp normalize_sort_order(order) when order in @sort_orders, do: order

  defp normalize_sort_order(order),
    do:
      raise(
        "Invalid sorting value :#{order}, please use either :asc, :asc_nulls_first, " <>
          ":asc_nulls_last, :desc, :desc_nulls_first or :desc_nulls_last"
      )

  defp reverse_sort_order(:asc), do: :desc
  defp reverse_sort_order(:desc), do: :asc
  defp reverse_sort_order(:asc_nulls_first), do: :desc_nulls_last
  defp reverse_sort_order(:asc_nulls_last), do: :desc_nulls_first
  defp reverse_sort_order(:desc_nulls_first), do: :asc_nulls_last
  defp reverse_sort_order(:desc_nulls_last), do: :asc_nulls_first

  # Fetching records before a cursor is the same as fetching records after it
  # with every sort order reversed.
  defp cursor_sort_order(order, :after), do: normalize_sort_order(order)

  defp cursor_sort_order(order, :before),
    do: order |> normalize_sort_order() |> reverse_sort_order()

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

  defp build_filters(query, [{bound_column, order} | rest], values, cursor_direction) do
    {position, column} = column_position(query, bound_column)
    value = Map.get(values, bound_column)

    next_filters =
      case rest do
        [] -> nil
        _ -> build_filters(query, rest, values, cursor_direction)
      end

    order
    |> cursor_sort_order(cursor_direction)
    |> build_filter(position, column, value, next_filters)
  end

  # Builds the filter matching records sorted strictly after the cursor value.
  # `next_filters` holds the filters for the remaining cursor fields, used to
  # break ties, and is `nil` for the last cursor field.
  defp build_filter(:asc_nulls_last, position, column, nil, next_filters),
    do: tie_filter(position, column, nil, next_filters)

  defp build_filter(:asc_nulls_last, position, column, value, next_filters) do
    dynamic([{q, position}], field(q, ^column) > ^value or is_nil(field(q, ^column)))
    |> or_tie_filter(position, column, value, next_filters)
  end

  defp build_filter(:asc_nulls_first, position, column, nil, next_filters) do
    dynamic([{q, position}], not is_nil(field(q, ^column)))
    |> or_tie_filter(position, column, nil, next_filters)
  end

  defp build_filter(:asc_nulls_first, position, column, value, next_filters) do
    dynamic([{q, position}], field(q, ^column) > ^value)
    |> or_tie_filter(position, column, value, next_filters)
  end

  defp build_filter(:desc_nulls_first, position, column, nil, next_filters) do
    dynamic([{q, position}], not is_nil(field(q, ^column)))
    |> or_tie_filter(position, column, nil, next_filters)
  end

  defp build_filter(:desc_nulls_first, position, column, value, next_filters) do
    dynamic([{q, position}], field(q, ^column) < ^value)
    |> or_tie_filter(position, column, value, next_filters)
  end

  defp build_filter(:desc_nulls_last, position, column, nil, next_filters),
    do: tie_filter(position, column, nil, next_filters)

  defp build_filter(:desc_nulls_last, position, column, value, next_filters) do
    dynamic([{q, position}], field(q, ^column) < ^value or is_nil(field(q, ^column)))
    |> or_tie_filter(position, column, value, next_filters)
  end

  defp or_tie_filter(filter, _position, _column, _value, nil), do: filter

  defp or_tie_filter(filter, position, column, value, next_filters) do
    tie_filter = tie_filter(position, column, value, next_filters)
    dynamic(^filter or ^tie_filter)
  end

  defp tie_filter(_position, _column, _value, nil), do: false

  defp tie_filter(position, column, nil, next_filters),
    do: dynamic([{q, position}], is_nil(field(q, ^column)) and ^next_filters)

  defp tie_filter(position, column, value, next_filters),
    do: dynamic([{q, position}], field(q, ^column) == ^value and ^next_filters)

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
                Enum.map(expr, fn {direction, ast} ->
                  {reverse_sort_order(direction), ast}
                end)
          }
        end
    end)
  end
end
