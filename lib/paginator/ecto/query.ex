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
    filters = build_where_expression(query, fields, values, cursor_direction)

    where(query, [{q, 0}], ^filters)
  end

  # Keeps the records strictly past the cursor by comparing the cursor fields
  # lexicographically:
  #
  #     past(field_1) OR (tied(field_1) AND (past(field_2) OR (tied(field_2) AND ...)))
  defp build_where_expression(query, [{column, order} | fields], values, cursor_direction) do
    value = Map.get(values, column)
    {position, column} = column_position(query, column)
    {operator, nulls} = comparison(order, cursor_direction)
    past = past_value(position, column, value, operator, nulls)

    case fields do
      [] when is_nil(value) ->
        raise("unstable sort order: nullable columns can't be used as the last term")

      [] ->
        past

      fields ->
        next_filters = build_where_expression(query, fields, values, cursor_direction)
        tied = tied_value(position, column, value, next_filters)

        if past, do: dynamic(^past or ^tied), else: tied
    end
  end

  # How a column is traversed when moving past the cursor: the operator
  # matching the non-null values that come next, and whether null values are
  # reached before (`:nulls_first`) or after (`:nulls_last`) all of them.
  # `:asc` and `:desc` follow the PostgreSQL defaults, where nulls sort as if
  # larger than any other value.
  defp comparison(order, :after) when order in [:asc, :asc_nulls_last], do: {:gt, :nulls_last}
  defp comparison(:asc_nulls_first, :after), do: {:gt, :nulls_first}
  defp comparison(order, :after) when order in [:desc, :desc_nulls_first], do: {:lt, :nulls_first}
  defp comparison(:desc_nulls_last, :after), do: {:lt, :nulls_last}
  defp comparison(order, :before) when order in [:asc, :asc_nulls_last], do: {:lt, :nulls_first}
  defp comparison(:asc_nulls_first, :before), do: {:lt, :nulls_last}
  defp comparison(order, :before) when order in [:desc, :desc_nulls_first], do: {:gt, :nulls_last}
  defp comparison(:desc_nulls_last, :before), do: {:gt, :nulls_first}

  defp comparison(order, _cursor_direction) do
    raise(
      "Invalid sorting value :#{order}, please use one of :asc, :asc_nulls_last, " <>
        ":asc_nulls_first, :desc, :desc_nulls_first or :desc_nulls_last"
    )
  end

  # Returns `nil` when no value can come past `value`.
  defp past_value(_position, _column, nil, _operator, :nulls_last), do: nil

  defp past_value(position, column, nil, _operator, :nulls_first),
    do: dynamic([{q, position}], not is_nil(field(q, ^column)))

  defp past_value(position, column, value, operator, :nulls_first),
    do: compare(position, column, operator, value)

  defp past_value(position, column, value, operator, :nulls_last) do
    compared = compare(position, column, operator, value)
    dynamic([{q, position}], ^compared or is_nil(field(q, ^column)))
  end

  defp compare(position, column, :gt, value),
    do: dynamic([{q, position}], field(q, ^column) > ^value)

  defp compare(position, column, :lt, value),
    do: dynamic([{q, position}], field(q, ^column) < ^value)

  defp tied_value(position, column, nil, next_filters),
    do: dynamic([{q, position}], is_nil(field(q, ^column)) and ^next_filters)

  defp tied_value(position, column, value, next_filters),
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
