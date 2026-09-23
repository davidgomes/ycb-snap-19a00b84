defmodule Paginator.Ecto.Query do
  @moduledoc false

  import Ecto.Query

  alias Paginator.Config

  @orders [:asc, :asc_nulls_first, :asc_nulls_last, :desc, :desc_nulls_first, :desc_nulls_last]

  @reversed_orders %{
    asc: :desc,
    asc_nulls_first: :desc_nulls_last,
    asc_nulls_last: :desc_nulls_first,
    desc: :asc,
    desc_nulls_first: :asc_nulls_last,
    desc_nulls_last: :asc_nulls_first
  }

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

  # Describes the values sorted after a cursor value: the operator the non-NULL
  # ones satisfy against it and whether NULLs sort first or last. As in PostgreSQL,
  # `:asc` and `:desc` sort NULLs as if they were larger than any other value.
  defp cursor_comparison(order, :before) when order in @orders,
    do: cursor_comparison(Map.fetch!(@reversed_orders, order), :after)

  defp cursor_comparison(order, :after) when order in [:asc, :asc_nulls_last],
    do: {:gt, :nulls_last}

  defp cursor_comparison(:asc_nulls_first, :after), do: {:gt, :nulls_first}

  defp cursor_comparison(order, :after) when order in [:desc, :desc_nulls_first],
    do: {:lt, :nulls_first}

  defp cursor_comparison(:desc_nulls_last, :after), do: {:lt, :nulls_last}

  defp cursor_comparison(order, _),
    do:
      raise(
        "Invalid sorting value #{inspect(order)}, please use one of " <>
          Enum.map_join(@orders, ", ", &inspect/1)
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
    where(query, [{q, 0}], ^build_where_expression(query, fields, values, cursor_direction))
  end

  # Matches the records sorted beyond the cursor on the first field, or tied with
  # the cursor on it and beyond the cursor on the remaining fields.
  defp build_where_expression(query, [{bound_column, order} | fields], values, cursor_direction) do
    {position, column} = column_position(query, bound_column)
    value = Map.get(values, bound_column)
    {operator, nulls} = cursor_comparison(order, cursor_direction)
    beyond = beyond_cursor(position, column, operator, nulls, value)

    case fields do
      [] ->
        beyond

      _ ->
        tied = tied_with_cursor(position, column, value)
        next = build_where_expression(query, fields, values, cursor_direction)
        dynamic((^tied and ^next) or ^beyond)
    end
  end

  defp tied_with_cursor(position, column, nil),
    do: dynamic([{q, position}], is_nil(field(q, ^column)))

  defp tied_with_cursor(position, column, value),
    do: dynamic([{q, position}], field(q, ^column) == ^value)

  defp beyond_cursor(position, column, _operator, :nulls_first, nil),
    do: dynamic([{q, position}], not is_nil(field(q, ^column)))

  defp beyond_cursor(_position, _column, _operator, :nulls_last, nil),
    do: dynamic(false)

  defp beyond_cursor(position, column, :gt, :nulls_first, value),
    do: dynamic([{q, position}], field(q, ^column) > ^value)

  defp beyond_cursor(position, column, :gt, :nulls_last, value),
    do: dynamic([{q, position}], field(q, ^column) > ^value or is_nil(field(q, ^column)))

  defp beyond_cursor(position, column, :lt, :nulls_first, value),
    do: dynamic([{q, position}], field(q, ^column) < ^value)

  defp beyond_cursor(position, column, :lt, :nulls_last, value),
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

  # This code was adapted from https://github.com/elixir-ecto/ecto/blob/v3.6.2/lib/ecto/query.ex#L2106-L2130
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
                  {Map.fetch!(@reversed_orders, direction), ast}
                end)
          }
        end
    end)
  end
end
