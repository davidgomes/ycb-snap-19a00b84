defmodule EctoShorts.QueryBuilderTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.QueryBuilder

  alias EctoShorts.QueryBuilder
  alias EctoShorts.Support.Schemas.{Comment, Post}

  require Ecto.Query

  defmodule MockAdapter do
    @moduledoc false
    @behaviour EctoShorts.QueryBuilder

    @impl EctoShorts.QueryBuilder
    def build_query(queryable, filter_key, filter_value, query) do
      send(self(), {:build_query, queryable, filter_key, filter_value, query})

      query
    end
  end

  describe "build_query: " do
    test "invokes the adapter with the queryable, filter key, filter value and query" do
      query = Ecto.Query.from(Comment)

      assert ^query = QueryBuilder.build_query(MockAdapter, Comment, :body, "body", query)

      assert_received {:build_query, Comment, :body, "body", ^query}
    end

    test "returns query built by the common adapter" do
      query = QueryBuilder.build_query(QueryBuilder.Common, Post, :first, 10, Post)

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

    test "returns query built by the schema adapter" do
      query = QueryBuilder.build_query(QueryBuilder.Schema, Post, :id, 1, Post)

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
  end
end
