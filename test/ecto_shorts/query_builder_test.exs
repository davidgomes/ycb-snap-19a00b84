defmodule EctoShorts.QueryBuilderTest do
  use ExUnit.Case, async: true

  doctest EctoShorts.QueryBuilder

  alias EctoShorts.QueryBuilder
  alias EctoShorts.QueryBuilder.{Common, Schema}
  alias EctoShorts.Support.Schemas.Post

  describe "create_schema_filter/4" do
    test "dispatches to the adapter's create_schema_filter/3 callback" do
      query = QueryBuilder.create_schema_filter(Schema, Post, :id, 1)

      assert %Ecto.Query{wheres: [_]} = query
    end

    test "adapter callbacks can be chained with the query first" do
      query =
        Post
        |> Schema.create_schema_filter(:id, 1)
        |> Common.create_schema_filter(:first, 10)

      assert %Ecto.Query{wheres: [_]} = query
      refute is_nil(query.limit)
    end
  end
end
