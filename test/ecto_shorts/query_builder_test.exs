defmodule EctoShorts.QueryBuilderTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.QueryBuilder

  alias EctoShorts.QueryBuilder
  alias EctoShorts.Support.Schemas.Post

  describe "create_schema_filter: " do
    test "returns query built by the common builder" do
      query = QueryBuilder.create_schema_filter(QueryBuilder.Common, Post, :first, 100)

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"posts", EctoShorts.Support.Schemas.Post}
        },
        limit: %Ecto.Query.LimitExpr{
          expr: {:^, [], [0]},
          params: [{100, :integer}]
        },
        wheres: []
      } = query
    end

    test "returns query built by the schema builder" do
      query = QueryBuilder.create_schema_filter(QueryBuilder.Schema, Post, :id, 1)

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"posts", EctoShorts.Support.Schemas.Post}
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:==, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{1, {0, :id}}]
          }
        ]
      } = query
    end
  end
end
