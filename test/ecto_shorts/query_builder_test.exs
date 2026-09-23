defmodule EctoShorts.QueryBuilderTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.QueryBuilder

  alias EctoShorts.QueryBuilder
  alias EctoShorts.Support.Schemas.Post

  describe "create_schema_filter: " do
    test "invokes the builder callback with query, filter key and filter value" do
      assert %Ecto.Query{
        limit: %Ecto.Query.LimitExpr{params: [{10, :integer}]}
      } = QueryBuilder.create_schema_filter(QueryBuilder.Common, Post, :first, 10)
    end
  end
end
