defmodule EctoShorts.QueryBuilder do
  @moduledoc """
  Behaviour for building queries from filters.

  Adapters implement `c:create_schema_filter/3`, which takes the
  query as the first argument so calls can be piped together:

  ```elixir
  EctoShorts.Support.Schemas.Post
  |> EctoShorts.QueryBuilder.Schema.create_schema_filter(:id, 1)
  |> EctoShorts.QueryBuilder.Common.create_schema_filter(:first, 10)
  ```
  """

  @type filter_key :: atom()
  @type filter_value :: any()
  @type query :: Ecto.Query.t()
  @type queryable :: Ecto.Queryable.t()

  @doc "Adds a filter to the query for the given filter key and value"
  @callback create_schema_filter(
    query :: query() | queryable(),
    filter_key :: filter_key(),
    filter_value :: filter_value()
  ) :: query() | queryable()

  @doc """
  Calls `c:create_schema_filter/3` on the given builder module.

  ### Examples

      iex> query = EctoShorts.QueryBuilder.create_schema_filter(
      ...>   EctoShorts.QueryBuilder.Common,
      ...>   EctoShorts.Support.Schemas.Post,
      ...>   :first,
      ...>   10
      ...> )
      iex> query.limit.params
      [{10, :integer}]
  """
  @spec create_schema_filter(
    builder :: module(),
    query :: query() | queryable(),
    filter_key :: filter_key(),
    filter_value :: filter_value()
  ) :: query() | queryable()
  def create_schema_filter(builder, query, filter_key, filter_value) do
    builder.create_schema_filter(query, filter_key, filter_value)
  end

  @spec query_schema(Ecto.Queryable.t) :: Ecto.Queryable.t()
  @doc "Pulls the schema from a query"
  def query_schema(%{from: %{source: {_, schema}}}), do: query_schema(schema)
  def query_schema(%{from: %{query: %{from: {_, schema}}}}), do: schema
  def query_schema(query), do: query
end
