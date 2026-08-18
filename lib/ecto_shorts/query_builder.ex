defmodule EctoShorts.QueryBuilder do
  @moduledoc "Behaviour for query building from filter tuples"

  @type adapter :: module()
  @type filter_key :: atom()
  @type filter_value :: any()
  @type query :: Ecto.Query.t()
  @type queryable :: Ecto.Queryable.t()

  @doc "Adds to accumulator query with filter_key and filter_value"
  @callback create_schema_filter(query(), filter_key(), filter_value()) :: query()

  @spec create_schema_filter(adapter(), query(), filter_key(), filter_value()) :: query()
  def create_schema_filter(adapter, query, filter_key, filter_value) do
    adapter.create_schema_filter(query, filter_key, filter_value)
  end

  @spec query_schema(Ecto.Queryable.t) :: Ecto.Queryable.t()
  @doc "Pulls the schema from a query"
  def query_schema(%{from: %{source: {_, schema}}}), do: query_schema(schema)
  def query_schema(%{from: %{query: %{from: {_, schema}}}}), do: schema
  def query_schema(query), do: query
end
