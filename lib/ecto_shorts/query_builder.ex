defmodule EctoShorts.QueryBuilder do
  @moduledoc "Behaviour for query building from filter keys and values"

  @type query :: Ecto.Query.t()
  @type queryable :: Ecto.Queryable.t()
  @type filter_key :: atom()
  @type filter_value :: any()

  @doc "Adds to the query a filter built from `filter_key` and `filter_value`"
  @callback create_schema_filter(
    query :: query() | queryable(),
    filter_key :: filter_key(),
    filter_value :: filter_value()
  ) :: query()

  @doc """
  Invokes `c:create_schema_filter/3` on the given `builder` module.

  ### Examples

      iex> EctoShorts.QueryBuilder.create_schema_filter(EctoShorts.QueryBuilder.Common, EctoShorts.Support.Schemas.Post, :first, 1_000)
      iex> EctoShorts.QueryBuilder.create_schema_filter(EctoShorts.QueryBuilder.Schema, EctoShorts.Support.Schemas.Post, :comments, %{id: 1})
  """
  @spec create_schema_filter(
    builder :: module(),
    query :: query() | queryable(),
    filter_key :: filter_key(),
    filter_value :: filter_value()
  ) :: query()
  def create_schema_filter(builder, query, filter_key, filter_value) do
    builder.create_schema_filter(query, filter_key, filter_value)
  end
end
