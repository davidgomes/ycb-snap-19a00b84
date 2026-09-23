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

  @order_directions [
    :asc,
    :asc_nulls_first,
    :asc_nulls_last,
    :desc,
    :desc_nulls_first,
    :desc_nulls_last
  ]

  # Normalizes a sort order into `{direction, nulls_position}` following PostgreSQL
  # defaults: NULLS LAST for ascending and NULLS FIRST for descending order.
  defp normalize_order(:asc), do: {:asc, :nulls_last}
  defp normalize_order(:asc_nulls_last), do: {:asc, :nulls_last}
  defp normalize_order(:asc_nulls_first), do: {:asc, :nulls_first}
  defp normalize_order(:desc), do: {:desc, :nulls_first}
  defp normalize_order(:desc_nulls_first), do: {:desc, :nulls_first}
  defp normalize_order(:desc_nulls_last), do: {:desc, :nulls_last}

  defp normalize_order(order),
    do:
      raise(
        "Invalid sorting value #{inspect(order)}, please use one of " <>
          Enum.map_join(@order_directions, ", ", &inspect/1)
      )

  # Fetching records before a cursor is the same as fetching records after it
  # in the reversed sort order.
  defp effective_order(order, :after), do: normalize_order(order)

  defp effective_order(order, :before) do
    case normalize_order(order) do
      {:asc, :nulls_last} -> {:desc, :nulls_first}
      {:asc, :nulls_first} -> {:desc, :nulls_last}
      {:desc, :nulls_first} -> {:asc, :nulls_last}
      {:desc, :nulls_last} -> {:asc, :nulls_first}
    end
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
    filters =
      fields
      |> Enum.reverse()
      |> Enum.reduce(false, fn {bound_column, order}, next_filters ->
        {position, column} = column_position(query, bound_column)
        value = Map.get(values, bound_column)

        build_filter(
          effective_order(order, cursor_direction),
          position,
          column,
          value,
          next_filters
        )
      end)

    case filters do
      false -> where(query, [], false)
      filters -> where(query, ^filters)
    end
  end

  # Builds the condition matching records that come strictly after the cursor
  # `value` for `column`, falling back to `next_filters` (the condition on the
  # remaining cursor fields) when the record ties with the cursor on `column`.
  # `next_filters` is `false` for the last cursor field.
  defp build_filter({_direction, :nulls_last}, position, column, nil, next_filters) do
    and_filters(dynamic([{q, position}], is_nil(field(q, ^column))), next_filters)
  end

  defp build_filter({_direction, :nulls_first}, position, column, nil, next_filters) do
    dynamic([{q, position}], not is_nil(field(q, ^column)))
    |> or_filters(and_filters(dynamic([{q, position}], is_nil(field(q, ^column))), next_filters))
  end

  defp build_filter({direction, nulls}, position, column, value, next_filters) do
    filters = greater_than(direction, position, column, value)

    filters =
      case nulls do
        :nulls_last -> or_filters(filters, dynamic([{q, position}], is_nil(field(q, ^column))))
        :nulls_first -> filters
      end

    or_filters(
      filters,
      and_filters(dynamic([{q, position}], field(q, ^column) == ^value), next_filters)
    )
  end

  defp greater_than(:asc, position, column, value),
    do: dynamic([{q, position}], field(q, ^column) > ^value)

  defp greater_than(:desc, position, column, value),
    do: dynamic([{q, position}], field(q, ^column) < ^value)

  defp and_filters(_left, false), do: false
  defp and_filters(left, right), do: dynamic(^left and ^right)

  defp or_filters(left, false), do: left
  defp or_filters(false, right), do: right
  defp or_filters(left, right), do: dynamic(^left or ^right)

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
                  {:desc, ast} -> {:asc, ast}
                  {:desc_nulls_first, ast} -> {:asc_nulls_last, ast}
                  {:desc_nulls_last, ast} -> {:asc_nulls_first, ast}
                  {:asc, ast} -> {:desc, ast}
                  {:asc_nulls_last, ast} -> {:desc_nulls_first, ast}
                  {:asc_nulls_first, ast} -> {:desc_nulls_last, ast}
                end)
          }
        end
    end)
  end
end
