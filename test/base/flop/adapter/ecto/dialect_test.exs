defmodule Flop.Adapter.Ecto.DialectTest do
  use ExUnit.Case, async: true

  alias Flop.Adapter.Ecto.Dialect

  @order_directions [
    :asc,
    :asc_nulls_first,
    :asc_nulls_last,
    :desc,
    :desc_nulls_first,
    :desc_nulls_last
  ]

  defmodule PostgresRepo do
    def __adapter__, do: Ecto.Adapters.Postgres
  end

  defmodule MyXQLRepo do
    def __adapter__, do: Ecto.Adapters.MyXQL
  end

  defmodule SQLite3Repo do
    def __adapter__, do: Ecto.Adapters.SQLite3
  end

  defmodule UnknownRepo do
    def __adapter__, do: SomeApp.Adapters.Unknown
  end

  describe "new/1" do
    test "reads the features of a known adapter" do
      assert Dialect.new(PostgresRepo) ==
               %Dialect{
                 arrays?: true,
                 ilike?: true,
                 nulls_largest?: true,
                 nulls_ordering?: true
               }

      assert Dialect.new(MyXQLRepo) ==
               %Dialect{
                 arrays?: false,
                 ilike?: false,
                 nulls_largest?: false,
                 nulls_ordering?: false
               }

      assert Dialect.new(SQLite3Repo) ==
               %Dialect{
                 arrays?: true,
                 ilike?: false,
                 nulls_largest?: false,
                 nulls_ordering?: true
               }
    end

    test "returns the defaults for an unknown adapter" do
      assert Dialect.new(UnknownRepo) == %Dialect{}
    end

    test "returns the defaults without a repo" do
      assert Dialect.new(nil) == %Dialect{}
      assert Dialect.new(NotARealRepo) == %Dialect{}
    end

    test "defaults to leaving the query unmodified" do
      assert %Dialect{} ==
               %Dialect{
                 arrays?: true,
                 ilike?: true,
                 nulls_largest?: true,
                 nulls_ordering?: true
               }
    end
  end

  describe "nulls_first?/2" do
    test "follows the explicit nulls directions on every adapter" do
      for repo <- [PostgresRepo, MyXQLRepo, SQLite3Repo, nil] do
        dialect = Dialect.new(repo)
        assert Dialect.nulls_first?(dialect, :asc_nulls_first)
        assert Dialect.nulls_first?(dialect, :desc_nulls_first)
        refute Dialect.nulls_first?(dialect, :asc_nulls_last)
        refute Dialect.nulls_first?(dialect, :desc_nulls_last)
      end
    end

    test "sorts NULLs as the largest value on PostgreSQL and by default" do
      for repo <- [PostgresRepo, UnknownRepo, nil] do
        refute Dialect.nulls_first?(Dialect.new(repo), :asc)
        assert Dialect.nulls_first?(Dialect.new(repo), :desc)
      end
    end

    test "sorts NULLs as the smallest value on MySQL and SQLite" do
      for repo <- [MyXQLRepo, SQLite3Repo] do
        assert Dialect.nulls_first?(Dialect.new(repo), :asc)
        refute Dialect.nulls_first?(Dialect.new(repo), :desc)
      end
    end
  end

  describe "the query built for a cursor" do
    test "compares a value where the NULLs come first" do
      assert cursor_where_clause(PostgresRepo, :asc_nulls_first, "Ada") ==
               ~S|p0.name > type(^"Ada", p0.name)|
    end

    test "adds the NULLs to a value where they come last" do
      assert cursor_where_clause(PostgresRepo, :asc_nulls_last, "Ada") ==
               ~S|p0.name > type(^"Ada", p0.name) or is_nil(p0.name)|
    end

    test "matches the values after NULL where the NULLs come first" do
      assert cursor_where_clause(PostgresRepo, :asc_nulls_first, nil) ==
               ~S|not is_nil(p0.name)|
    end

    test "matches no row after NULL where the NULLs come last" do
      assert cursor_where_clause(PostgresRepo, :asc_nulls_last, nil) ==
               "false"
    end

    test "places the NULLs by adapter for the plain directions" do
      assert cursor_where_clause(PostgresRepo, :asc, nil) ==
               cursor_where_clause(PostgresRepo, :asc_nulls_last, nil)

      assert cursor_where_clause(SQLite3Repo, :asc, nil) ==
               cursor_where_clause(SQLite3Repo, :asc_nulls_first, nil)

      assert cursor_where_clause(MyXQLRepo, :desc, nil) ==
               cursor_where_clause(MyXQLRepo, :desc_nulls_last, nil)
    end

    test "falls through to the next order field on NULL" do
      assert cursor_where_clause(PostgresRepo, :asc_nulls_last, nil, 3) ==
               ~S|is_nil(p0.name) and p0.age > type(^3, p0.age)|

      assert cursor_where_clause(PostgresRepo, :asc_nulls_first, nil, 3) ==
               ~S|not is_nil(p0.name) or p0.age > type(^3, p0.age)|
    end
  end

  defp cursor_where_clause(repo, direction, name) do
    where_clause_for_cursor(repo, [:name], [direction], %{name: name})
  end

  defp cursor_where_clause(repo, direction, name, age) do
    where_clause_for_cursor(
      repo,
      [:name, :age],
      [direction, :asc_nulls_first],
      %{name: name, age: age}
    )
  end

  defp where_clause_for_cursor(repo, order_by, directions, cursor) do
    flop = %Flop{
      first: 1,
      after: Flop.Cursor.encode(cursor),
      order_by: order_by,
      order_directions: directions
    }

    MyApp.Pet
    |> Flop.query(flop, for: MyApp.Pet, repo: repo)
    |> inspect()
    |> String.split("where: ")
    |> List.last()
    |> String.split(", order_by: ")
    |> List.first()
  end

  describe "the query built for the case-insensitive operators" do
    test "uses ILIKE on an adapter that has it" do
      assert where_clause(PostgresRepo) ==
               ~S|ilike(p0.name, ^"%abc%")|
    end

    test "uses LIKE with an ESCAPE clause on an adapter that does not" do
      assert where_clause(SQLite3Repo) ==
               ~S|fragment("? LIKE ? ESCAPE ?", p0.name, ^"%abc%", ^"\\")|

      assert where_clause(MyXQLRepo) == where_clause(SQLite3Repo)
    end

    test "uses ILIKE when no repo is configured" do
      assert where_clause(nil) == where_clause(PostgresRepo)
    end
  end

  describe "order_direction/2" do
    test "keeps the direction on an adapter with NULLS FIRST and NULLS LAST" do
      for direction <- @order_directions do
        assert Dialect.order_direction(Dialect.new(PostgresRepo), direction) ==
                 {:native, direction}
      end
    end

    test "maps the nulls directions on an adapter without them" do
      assert Dialect.order_direction(Dialect.new(MyXQLRepo), :asc) ==
               {:native, :asc}

      assert Dialect.order_direction(Dialect.new(MyXQLRepo), :desc) ==
               {:native, :desc}

      assert Dialect.order_direction(Dialect.new(MyXQLRepo), :asc_nulls_first) ==
               {:native, :asc}

      assert Dialect.order_direction(Dialect.new(MyXQLRepo), :desc_nulls_last) ==
               {:native, :desc}

      assert Dialect.order_direction(Dialect.new(MyXQLRepo), :asc_nulls_last) ==
               {:emulated, :asc}

      assert Dialect.order_direction(Dialect.new(MyXQLRepo), :desc_nulls_first) ==
               {:emulated, :desc}
    end

    test "keeps the direction for an unknown adapter" do
      assert Dialect.order_direction(Dialect.new(UnknownRepo), :asc_nulls_last) ==
               {:native, :asc_nulls_last}
    end

    test "keeps the direction without a repo" do
      assert Dialect.order_direction(Dialect.new(nil), :asc_nulls_last) ==
               {:native, :asc_nulls_last}

      assert Dialect.order_direction(Dialect.new(NotARealRepo), :asc_nulls_last) ==
               {:native, :asc_nulls_last}
    end
  end

  describe "the query built for the nulls order directions" do
    test "uses them on an adapter that has them" do
      for direction <- @order_directions do
        assert order_by_clause(PostgresRepo, direction) ==
                 "[#{direction}: p0.name]"
      end
    end

    test "uses the plain direction where the adapter already sorts that way" do
      assert order_by_clause(MyXQLRepo, :asc_nulls_first) == "[asc: p0.name]"
      assert order_by_clause(MyXQLRepo, :desc_nulls_last) == "[desc: p0.name]"
    end

    test "sorts on IS NULL first where it does not" do
      assert order_by_clause(MyXQLRepo, :asc_nulls_last) ==
               ~S|[asc: fragment("? IS NULL", p0.name), asc: p0.name]|

      assert order_by_clause(MyXQLRepo, :desc_nulls_first) ==
               ~S|[desc: fragment("? IS NULL", p0.name), desc: p0.name]|
    end
  end

  defp order_by_clause(repo, direction) do
    flop = %Flop{order_by: [:name], order_directions: [direction]}

    MyApp.Pet
    |> Flop.query(flop, for: MyApp.Pet, repo: repo)
    |> inspect()
    |> String.split("order_by: ")
    |> List.last()
    |> String.trim_trailing(">")
  end

  describe "the query built for the array operators" do
    test "uses the array itself on an adapter that has one" do
      assert where_clause(PostgresRepo, :tags, :contains, "pear") ==
               ~S|^"pear" in p0.tags|

      assert where_clause(PostgresRepo, :tags, :not_contains, "pear") ==
               ~S|^"pear" not in p0.tags|

      assert where_clause(PostgresRepo, :tags, :empty, true) ==
               ~S|is_nil(p0.tags) or p0.tags == type(^[], {:array, :string})|
    end

    test "uses the JSON functions on an adapter that has no array type" do
      assert where_clause(MyXQLRepo, :tags, :contains, "pear") ==
               ~S|fragment("JSON_CONTAINS(?, ?)", p0.tags, ^["pear"])|

      assert where_clause(MyXQLRepo, :tags, :not_contains, "pear") ==
               ~S|not fragment("JSON_CONTAINS(?, ?)", p0.tags, ^["pear"])|

      assert where_clause(MyXQLRepo, :tags, :empty, true) ==
               ~S|is_nil(p0.tags) or fragment("JSON_LENGTH(?) = 0", p0.tags)|
    end

    test "dumps the value with the element type of the field" do
      assert Dialect.dump_array_element("pear", {:array, :string}) == "pear"

      assert Dialect.dump_array_element(~D[2026-08-13], {:array, :date}) ==
               ~D[2026-08-13]
    end

    test "passes the value through when it has no type to dump it with" do
      assert Dialect.dump_array_element("pear", nil) == "pear"
      assert Dialect.dump_array_element("pear", {:array, :integer}) == "pear"
    end
  end

  defp where_clause(repo) do
    flop = %Flop{
      filters: [%Flop.Filter{field: :name, op: :ilike, value: "abc"}]
    }

    MyApp.Pet
    |> Flop.query(flop, for: MyApp.Pet, repo: repo)
    |> inspect()
    |> String.split("where: ")
    |> List.last()
    |> String.trim_trailing(">")
  end

  defp where_clause(repo, field, op, value) do
    flop = %Flop{filters: [%Flop.Filter{field: field, op: op, value: value}]}

    MyApp.Pet
    |> Flop.query(flop, for: MyApp.Pet, repo: repo)
    |> inspect()
    |> String.split("where: ")
    |> List.last()
    |> String.trim_trailing(">")
  end
end
