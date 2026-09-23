defmodule EctoShorts.QueryBuilder do
  @moduledoc "Behaviour for query building from filter tuples"

  @type query :: Ecto.Queryable.t()
  @type filter :: atom()
  @type value :: any()

  @doc "Adds to the query a filter for the given filter key and value"
  @callback create_schema_filter(query, filter, value) :: Ecto.Query.t()

  @spec create_schema_filter(module, query, filter, value) :: Ecto.Query.t()
  def create_schema_filter(builder, query, filter, value) do
    builder.create_schema_filter(query, filter, value)
  end

  @spec query_schema(Ecto.Queryable.t) :: Ecto.Queryable.t()
  @doc "Pulls the schema from a query"
  def query_schema(%{from: %{source: {_, schema}}}), do: query_schema(schema)
  def query_schema(%{from: %{query: %{from: {_, schema}}}}), do: schema
  def query_schema(query), do: query
end
