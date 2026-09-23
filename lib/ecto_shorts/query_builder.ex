defmodule EctoShorts.QueryBuilder do
  @moduledoc "Behaviour for query building from filter keys and values"

  @type query :: Ecto.Query.t()
  @type filter_key :: atom()
  @type filter_value :: any()

  @doc "Adds to the query with the filter key and value"
  @callback create_schema_filter(query(), filter_key(), filter_value()) :: query()

  @spec create_schema_filter(module(), query(), filter_key(), filter_value()) :: query()
  def create_schema_filter(builder, query, filter_key, filter_value) do
    builder.create_schema_filter(query, filter_key, filter_value)
  end

  @spec query_schema(Ecto.Queryable.t) :: Ecto.Queryable.t()
  @doc "Pulls the schema from a query"
  def query_schema(%{from: %{source: {_, schema}}}), do: query_schema(schema)
  def query_schema(%{from: %{query: %{from: {_, schema}}}}), do: schema
  def query_schema(query), do: query
end
