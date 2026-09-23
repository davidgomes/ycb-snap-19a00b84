defmodule EctoShorts.QueryBuilderTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.QueryBuilder

  alias EctoShorts.QueryBuilder
  alias EctoShorts.Support.Schemas.Post

  describe "create_schema_filter: " do
    test "returns query built by the given builder" do
      query = QueryBuilder.create_schema_filter(QueryBuilder.Common, Post, :first, 100)

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"posts", EctoShorts.Support.Schemas.Post}
        },
        limit: %Ecto.Query.LimitExpr{
          expr: {:^, [], [0]},
          params: [{100, :integer}],
          with_ties: false
        },
        wheres: []
      } = query
    end

    test "returns query when builder callbacks are chained" do
      query =
        Post
        |> QueryBuilder.Schema.create_schema_filter(:id, 1)
        |> QueryBuilder.Common.create_schema_filter(:first, 100)

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"posts", EctoShorts.Support.Schemas.Post}
        },
        limit: %Ecto.Query.LimitExpr{
          expr: {:^, [], [0]},
          params: [{100, :integer}],
          with_ties: false
        },
        wheres: [
          %Ecto.Query.BooleanExpr{
            expr: {:==, [], [{{:., [], [{:&, [], [0]}, :id]}, [], []}, {:^, [], [0]}]},
            op: :and,
            params: [{1, {0, :id}}],
            subqueries: []
          }
        ]
      } = query
    end
  end
end
