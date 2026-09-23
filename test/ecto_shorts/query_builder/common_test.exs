defmodule EctoShorts.QueryBuilder.CommonTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.QueryBuilder.Common

  alias EctoShorts.QueryBuilder.Common
  alias EctoShorts.Support.Schemas.{Comment, Post}

  require Ecto.Query

  describe "filters: " do
    test "returns expected list" do
      assert [
        :preload,
        :start_date,
        :end_date,
        :before,
        :after,
        :ids,
        :first,
        :last,
        :limit,
        :offset,
        :search,
        :order_by
      ] = Common.filters()
    end
  end

  describe "build_query: " do
    test "returns query without changes when searching a schema that does not define by_search/2" do
      expected_query = Comment

      assert ^expected_query = Common.build_query(Comment, :search, %{id: 1}, expected_query)
    end

    test "returns query built by by_search/2 of the given schema" do
      query = Common.build_query(Post, :search, %{id: 1}, Ecto.Query.from(Post))

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"posts", EctoShorts.Support.Schemas.Post}
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

    test "returns query with limit when passed :first" do
      query = Common.build_query(Post, :first, 10, Post)

      assert %Ecto.Query{
        from: %Ecto.Query.FromExpr{
          source: {"posts", EctoShorts.Support.Schemas.Post}
        },
        limit: %Ecto.Query.LimitExpr{
          expr: {:^, [], [0]},
          params: [{10, :integer}]
        }
      } = query
    end
  end
end
