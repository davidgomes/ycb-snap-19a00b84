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

  @asc_directions [:asc, :asc_nulls_first, :asc_nulls_last]
  @desc_directions [:desc, :desc_nulls_first, :desc_nulls_last]

  defp get_operator(order, :before) when order in @asc_directions, do: :lt
  defp get_operator(order, :before) when order in @desc_directions, do: :gt
  defp get_operator(order, :after) when order in @asc_directions, do: :gt
  defp get_operator(order, :after) when order in @desc_directions, do: :lt

  defp get_operator(direction, _),
    do:
      raise(
        "Invalid sorting value :#{direction}, please use either :asc, :asc_nulls_first, " <>
          ":asc_nulls_last, :desc, :desc_nulls_first or :desc_nulls_last"
      )

  # Whether NULLs come after non-NULL values when walking in `cursor_direction`.
  # `nil` means the NULL position is unspecified (plain :asc / :desc).
  defp nulls_after?(order, :after) when order in [:asc_nulls_last, :desc_nulls_last], do: true
  defp nulls_after?(order, :after) when order in [:asc_nulls_first, :desc_nulls_first], do: false
  defp nulls_after?(order, :before) when order in [:asc_nulls_first, :desc_nulls_first], do: true
  defp nulls_after?(order, :before) when order in [:asc_nulls_last, :desc_nulls_last], do: false
  defp nulls_after?(_order, _cursor_direction), do: nil

  defp get_order_for_field(cursor_fields, key) do
    {_, order} =
      cursor_fields
      |> Enum.find(fn {field_key, _order} ->
        field_key == key
      end)

    order
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
    sorts =
      fields
      |> Enum.map(fn {column, _order} -> {column, Map.get(values, column)} end)
      |> Enum.reject(fn {column, value} ->
        is_nil(value) and
          is_nil(nulls_after?(get_order_for_field(fields, column), cursor_direction))
      end)

    dynamic_sorts =
      sorts
      |> Enum.with_index()
      |> Enum.reduce(true, fn {{bound_column, value}, i}, dynamic_sorts ->
        {position, column} = column_position(query, bound_column)

        order = get_order_for_field(fields, bound_column)
        nulls_after = nulls_after?(order, cursor_direction)

        dynamic =
          case {get_operator(order, cursor_direction), value, nulls_after} do
            {_, nil, true} ->
              false

            {_, nil, false} ->
              dynamic([{q, position}], not is_nil(field(q, ^column)))

            {:lt, _, true} ->
              dynamic(
                [{q, position}],
                field(q, ^column) < ^value or is_nil(field(q, ^column))
              )

            {:gt, _, true} ->
              dynamic(
                [{q, position}],
                field(q, ^column) > ^value or is_nil(field(q, ^column))
              )

            {:lt, _, _} ->
              dynamic([{q, position}], field(q, ^column) < ^value)

            {:gt, _, _} ->
              dynamic([{q, position}], field(q, ^column) > ^value)
          end

        dynamic =
          sorts
          |> Enum.take(i)
          |> Enum.reduce(dynamic, fn {prev_column, prev_value}, dynamic ->
            {position, prev_column} = column_position(query, prev_column)
            if is_nil(prev_value) do
              dynamic([{q, position}], is_nil(field(q, ^prev_column)) and ^dynamic)
            else
              dynamic([{q, position}], field(q, ^prev_column) == ^prev_value and ^dynamic)
            end
          end)

        if i == 0 do
          dynamic([{q, position}], ^dynamic and ^dynamic_sorts)
        else
          dynamic([{q, position}], ^dynamic or ^dynamic_sorts)
        end
      end)

    where(query, [{q, 0}], ^dynamic_sorts)
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
