defmodule EctoShorts.QueryBuilder.Common do
  @moduledoc """
  This module contains query building parts for common things such
  as preload, start/end date and others
  """
  @moduledoc since: "2.5.0"

  import Logger, only: [debug: 1]
  import Ecto.Query, only: [
    offset: 2, preload: 2, where: 3, limit: 2,
    exclude: 2, from: 2, subquery: 1, order_by: 2
  ]

  alias EctoShorts.{
    QueryBuilder,
    QueryHelpers
  }

  @type filter_key :: atom()
  @type filter_value :: any()
  @type filters :: list(atom())
  @type query :: Ecto.Query.t()

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

  @doc """
  Returns the list of supported filters.

  ### Examples

      iex> EctoShorts.QueryBuilder.Common.filters()
      [
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
  """
  @spec filters :: filters()
  def filters, do: @filters

  @impl true
  @doc """
  Implementation for `c:EctoShorts.QueryBuilder.create_schema_filter/3`.

  ### Examples

      iex> EctoShorts.QueryBuilder.Common.create_schema_filter(EctoShorts.Support.Schemas.Post, :ids, [1])
  """
  @spec create_schema_filter(
    query :: query(),
    filter_key :: filter_key(),
    filter_value :: filter_value()
  ) :: query()
  def create_schema_filter(query, :preload, val), do: preload(query, ^val)

  def create_schema_filter(query, :start_date, val), do: where(query, [m], m.inserted_at >= ^(val))

  def create_schema_filter(query, :end_date, val), do: where(query, [m], m.inserted_at <= ^val)

  def create_schema_filter(query, :before, id), do: where(query, [m], m.id < ^id)

  def create_schema_filter(query, :after, id), do: where(query, [m], m.id > ^id)

  def create_schema_filter(query, :ids, ids), do: where(query, [m], m.id in ^ids)

  def create_schema_filter(query, :offset, val), do: offset(query, ^val)

  def create_schema_filter(query, :limit, val), do: limit(query, ^val)

  def create_schema_filter(query, :first, val), do: limit(query, ^val)

  def create_schema_filter(query, :order_by, val), do: order_by(query, ^val)

  def create_schema_filter(query, :last, val) do
    query
      |> exclude(:order_by)
      |> from(order_by: [desc: :inserted_at], limit: ^val)
      |> subquery
      |> order_by(:id)
  end

  def create_schema_filter(query, :search, val) do
    schema = QueryHelpers.get_queryable(query)

    if function_exported?(schema, :by_search, 2) do
      schema.by_search(query, val)
    else
      debug "create_schema_filter: #{inspect schema} doesn't define &search_by/2 (query, params)"

      query
    end
  end
end
