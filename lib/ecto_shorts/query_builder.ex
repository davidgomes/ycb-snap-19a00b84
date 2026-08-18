defmodule EctoShorts.QueryBuilder do
  @moduledoc """
  Specifies the query builder API required from adapters.
  """
  @moduledoc since: "2.5.0"

  @type adapter :: module()
  @type filter_key :: atom()
  @type filter_value :: any()
  @type query :: Ecto.Query.t()

  @doc """
  Adds an expression to a query for the given filter key and value.

  The query-first argument order allows adapter calls to be chained:

      iex> EctoShorts.Support.Schemas.Post
      ...> |> EctoShorts.QueryBuilder.Schema.create_schema_filter(:id, 1)
      ...> |> EctoShorts.QueryBuilder.Common.create_schema_filter(:first, 10)
      #Ecto.Query<from p0 in EctoShorts.Support.Schemas.Post, where: p0.id == ^1, limit: ^10>
  """
  @callback create_schema_filter(query(), filter_key(), filter_value()) :: query()

  @doc """
  Invokes `c:create_schema_filter/3` on the given adapter.

  ### Examples

      iex> EctoShorts.QueryBuilder.create_schema_filter(
      ...>   EctoShorts.QueryBuilder.Common,
      ...>   EctoShorts.Support.Schemas.Comment,
      ...>   :first,
      ...>   1_000
      ...> )
      #Ecto.Query<from c0 in EctoShorts.Support.Schemas.Comment, limit: ^1000>
  """
  @spec create_schema_filter(adapter(), query(), filter_key(), filter_value()) :: query()
  def create_schema_filter(adapter, query, filter_key, filter_value) do
    adapter.create_schema_filter(query, filter_key, filter_value)
  end
end
