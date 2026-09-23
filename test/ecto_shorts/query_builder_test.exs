defmodule EctoShorts.QueryBuilderTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.QueryBuilder

  alias EctoShorts.QueryBuilder
  alias EctoShorts.Support.Schemas.Post

  describe "create_schema_filter: " do
    test "calls the builder module with the query as the first argument" do
      query = QueryBuilder.create_schema_filter(QueryBuilder.Schema, Post, :id, 1)

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"posts", EctoShorts.Support.Schemas.Post}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:==, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]},
            params: [{1, {0, :id}}]
          }
        ]
      } = query
    end

    test "can pipe builder calls together" do
      query =
        Post
        |> QueryBuilder.Schema.create_schema_filter(:id, 1)
        |> QueryBuilder.Common.create_schema_filter(:first, 10)

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"posts", EctoShorts.Support.Schemas.Post}
        },
        limit: %Ecto.Query.LimitExpr{
          params: [{10, :integer}]
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            params: [{1, {0, :id}}]
          }
        ]
      } = query
    end
  end
end
