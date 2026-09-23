defmodule EctoShorts.QueryBuilder.Common do
  @moduledoc """
  This module contains query building parts for common things such
  as preload, start/end date and others
  """

  import Logger, only: [debug: 1]
  import Ecto.Query, only: [
    offset: 2, preload: 2, where: 3, limit: 2,
    exclude: 2, from: 2, subquery: 1, order_by: 2
  ]

  alias EctoShorts.QueryBuilder

  @behaviour QueryBuilder

  @filters [
    :preload,
    :start_date,
    :end_date,
    :before,
    :after,
    :ids,
    :first,
    :last,
    :limit,
    :offset,
    :search,
    :order_by
  ]

  @spec filters :: list(atom)
  def filters, do: @filters

  @impl QueryBuilder
  def build_query(_schema, :preload, val, query), do: preload(query, ^val)

  @impl QueryBuilder
  def build_query(_schema, :start_date, val, query), do: where(query, [m], m.inserted_at >= ^(val))

  @impl QueryBuilder
  def build_query(_schema, :end_date, val, query), do: where(query, [m], m.inserted_at <= ^val)

  @impl QueryBuilder
  def build_query(_schema, :before, id, query), do: where(query, [m], m.id < ^id)

  @impl QueryBuilder
  def build_query(_schema, :after, id, query), do: where(query, [m], m.id > ^id)

  @impl QueryBuilder
  def build_query(_schema, :ids, ids, query), do: where(query, [m], m.id in ^ids)

  @impl QueryBuilder
  def build_query(_schema, :offset, val, query), do: offset(query, ^val)

  @impl QueryBuilder
  def build_query(_schema, :limit, val, query), do: limit(query, ^val)

  @impl QueryBuilder
  def build_query(_schema, :first, val, query), do: limit(query, ^val)

  @impl QueryBuilder
  def build_query(_schema, :order_by, val, query), do: order_by(query, ^val)

  @impl QueryBuilder
  def build_query(_schema, :last, val, query) do
    query
      |> exclude(:order_by)
      |> from(order_by: [desc: :inserted_at], limit: ^val)
      |> subquery
      |> order_by(:id)
  end

  @impl QueryBuilder
  def build_query(schema, :search, val, query) do
    if function_exported?(schema, :by_search, 2) do
      schema.by_search(query, val)
    else
      debug "build_query: #{inspect schema} doesn't define &by_search/2 (query, params)"

      query
    end
  end
end
