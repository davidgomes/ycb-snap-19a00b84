defmodule EctoShorts.QueryBuilder do
  @moduledoc """
  Specifies the query builder API required from adapters.
  """

  @type adapter :: module()
  @type filter_key :: atom()
  @type filter_value :: any()
  @type query :: Ecto.Query.t()
  @type queryable :: Ecto.Queryable.t()

  @doc """
  Adds an expression to the query given a filter key and value.
  """
  @callback create_schema_filter(query(), filter_key(), filter_value()) :: query()

  @doc """
  Invokes the callback function `c:EctoShorts.QueryBuilder.create_schema_filter/3`
  on the given adapter.

  ### Examples

      iex> EctoShorts.QueryBuilder.create_schema_filter(
      ...>   EctoShorts.QueryBuilder.Common,
      ...>   EctoShorts.Support.Schemas.Comment,
      ...>   :first,
      ...>   1_000
      ...> )
  """
  @spec create_schema_filter(adapter(), query() | queryable(), filter_key(), filter_value()) :: query()
  def create_schema_filter(adapter, query, filter_key, filter_value) do
    adapter.create_schema_filter(query, filter_key, filter_value)
  end
end
