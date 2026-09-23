defmodule EctoShorts.QueryBuilder do
  @moduledoc "Behaviour for query building from filter keys and values"

  @type filter_key :: atom()
  @type filter_value :: any()
  @type query :: Ecto.Query.t()
  @type queryable :: Ecto.Queryable.t()

  @doc "Adds to the query with filter_key and filter_value"
  @callback create_schema_filter(
    query :: query() | queryable(),
    filter_key :: filter_key(),
    filter_value :: filter_value()
  ) :: query() | queryable()

  @spec create_schema_filter(
    builder :: module(),
    query :: query() | queryable(),
    filter_key :: filter_key(),
    filter_value :: filter_value()
  ) :: query() | queryable()
  def create_schema_filter(builder, query, filter_key, filter_value) do
    builder.create_schema_filter(query, filter_key, filter_value)
  end
end
