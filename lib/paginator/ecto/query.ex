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

  defp get_operator(order, :before) when order in [:asc, :asc_nulls_first, :asc_nulls_last],
    do: :lt

  defp get_operator(order, :before) when order in [:desc, :desc_nulls_first, :desc_nulls_last],
    do: :gt

  defp get_operator(order, :after) when order in [:asc, :asc_nulls_first, :asc_nulls_last],
    do: :gt

  defp get_operator(order, :after) when order in [:desc, :desc_nulls_first, :desc_nulls_last],
    do: :lt

  defp get_operator(direction, _),
    do:
      raise(
        "Invalid sorting value :#{direction}, please use one of #{inspect(@order_directions)}"
      )

  # Plain :asc and :desc keep the legacy behaviour of not taking NULLs into account.
  defp nulls_position(order) when order in [:asc_nulls_first, :desc_nulls_first], do: :first
  defp nulls_position(order) when order in [:asc_nulls_last, :desc_nulls_last], do: :last
  defp nulls_position(_order), do: nil

  # Whether NULL values sort strictly beyond any non-NULL value in the cursor direction.
  defp nulls_beyond?(order, :after), do: nulls_position(order) == :last
  defp nulls_beyond?(order, :before), do: nulls_position(order) == :first

  defp strict_filter(order, cursor_direction, position, column, nil) do
    if nulls_beyond?(order, cursor_direction) do
      false
    else
      dynamic([{q, position}], not is_nil(field(q, ^column)))
    end
  end

  defp strict_filter(order, cursor_direction, position, column, value) do
    dynamic =
      case get_operator(order, cursor_direction) do
        :lt -> dynamic([{q, position}], field(q, ^column) < ^value)
        :gt -> dynamic([{q, position}], field(q, ^column) > ^value)
      end

    if nulls_beyond?(order, cursor_direction) do
      dynamic([{q, position}], ^dynamic or is_nil(field(q, ^column)))
    else
      dynamic
    end
  end

  defp equal_filter(position, column, nil),
    do: dynamic([{q, position}], is_nil(field(q, ^column)))

  defp equal_filter(position, column, value),
    do: dynamic([{q, position}], field(q, ^column) == ^value)

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
      |> Enum.map(fn {column, order} -> {column, order, Map.get(values, column)} end)
      |> Enum.reject(fn {_column, order, value} ->
        is_nil(value) and is_nil(nulls_position(order))
      end)

    case sorts do
      [] ->
        query

      [_ | _] ->
        # Built from the last sort field backwards, each field contributes
        # `strictly_beyond(field) OR (equal(field) AND <filter for the remaining fields>)`.
        dynamic_sorts =
          sorts
          |> Enum.reverse()
          |> Enum.reduce(nil, fn {bound_column, order, value}, next_filters ->
            {position, column} = column_position(query, bound_column)
            strict = strict_filter(order, cursor_direction, position, column, value)

            case next_filters do
              nil ->
                strict

              next_filters ->
                equal = equal_filter(position, column, value)
                dynamic([{q, position}], ^strict or (^equal and ^next_filters))
            end
          end)

        where(query, [{q, 0}], ^dynamic_sorts)
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
            | expr:
                Enum.map(expr, fn
                  {:desc, ast} -> {:asc, ast}
                  {:asc, ast} -> {:desc, ast}
                  {:desc_nulls_first, ast} -> {:asc_nulls_last, ast}
                  {:desc_nulls_last, ast} -> {:asc_nulls_first, ast}
                  {:asc_nulls_first, ast} -> {:desc_nulls_last, ast}
                  {:asc_nulls_last, ast} -> {:desc_nulls_first, ast}
                end)
          }
        end
    end)
  end
end
