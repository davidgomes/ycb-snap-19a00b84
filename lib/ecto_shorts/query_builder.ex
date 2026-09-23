defmodule EctoShorts.QueryBuilder do
  @moduledoc """
  Specifies the query builder API required from adapters.

  An adapter receives the `Ecto.Queryable` (for example your ecto schema)
  the query is built on, the filter key and value, and the accumulator
  query that the filter is added to.
  """

  @type adapter :: module()
  @type filter_key :: atom()
  @type filter_value :: any()
  @type query :: Ecto.Query.t()
  @type queryable :: Ecto.Queryable.t()

  @doc "Adds to the accumulator query with the filter key and value"
  @callback build_query(
    queryable :: queryable(),
    filter_key :: filter_key(),
    filter_value :: filter_value(),
    query :: query()
  ) :: query()

  @doc """
  Invokes `c:build_query/4` on the given adapter.

  ### Examples

      iex> EctoShorts.QueryBuilder.build_query(
      ...>   EctoShorts.QueryBuilder.Common,
      ...>   EctoShorts.Support.Schemas.Post,
      ...>   :first,
      ...>   10,
      ...>   EctoShorts.Support.Schemas.Post
      ...> )
  """
  @spec build_query(
    adapter :: adapter(),
    queryable :: queryable(),
    filter_key :: filter_key(),
    filter_value :: filter_value(),
    query :: query()
  ) :: query()
  def build_query(adapter, queryable, filter_key, filter_value, query) do
    adapter.build_query(queryable, filter_key, filter_value, query)
  end
end
