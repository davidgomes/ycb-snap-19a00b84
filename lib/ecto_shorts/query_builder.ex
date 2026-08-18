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
  Adds an expression to the query given a filter key and value.

  The returned `Ecto.Query` is equivalent to one written with the `Ecto.Query`
  DSL.

  For example, the following function call:

  ```elixir
  iex> Ecto.Query.from(c in EctoShorts.Support.Schemas.Comment, where: c.id == 1)
  #Ecto.Query<from c0 in EctoShorts.Support.Schemas.Comment, where: c0.id == 1>
  ```

  is equivalent to:

  ```elixir
  iex> EctoShorts.QueryBuilder.create_schema_filter(
  ...>   EctoShorts.QueryBuilder.Schema,
  ...>   EctoShorts.Support.Schemas.Comment,
  ...>   :id,
  ...>   1
  ...> )
  #Ecto.Query<from c0 in EctoShorts.Support.Schemas.Comment, where: c0.id == ^1>
  ```
  """
  @callback create_schema_filter(query(), filter_key(), filter_value()) :: query()

  @doc """
  Invokes the callback function `c:EctoShorts.QueryBuilder.create_schema_filter/3`.

  Returns an `Ecto.Query`.

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
