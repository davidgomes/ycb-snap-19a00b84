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
                 nulls_ordering?: true,
                 asc_nulls: :last
               }

      assert Dialect.new(MyXQLRepo) ==
               %Dialect{
                 arrays?: false,
                 ilike?: false,
                 nulls_ordering?: false,
                 asc_nulls: :first
               }

      assert Dialect.new(SQLite3Repo) ==
               %Dialect{
                 arrays?: true,
                 ilike?: false,
                 nulls_ordering?: true,
                 asc_nulls: :first
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
                 nulls_ordering?: true,
                 asc_nulls: :last
               }
    end
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

  describe "nulls_position/2" do
    test "follows the adapter default for :asc and :desc" do
      assert Dialect.nulls_position(Dialect.new(PostgresRepo), :asc) == :last
      assert Dialect.nulls_position(Dialect.new(PostgresRepo), :desc) == :first

      assert Dialect.nulls_position(Dialect.new(SQLite3Repo), :asc) == :first
      assert Dialect.nulls_position(Dialect.new(SQLite3Repo), :desc) == :last

      assert Dialect.nulls_position(Dialect.new(MyXQLRepo), :asc) == :first
      assert Dialect.nulls_position(Dialect.new(MyXQLRepo), :desc) == :last
    end

    test "uses the position named by the direction" do
      for dialect <- [
            Dialect.new(PostgresRepo),
            Dialect.new(SQLite3Repo),
            Dialect.new(MyXQLRepo)
          ] do
        assert Dialect.nulls_position(dialect, :asc_nulls_first) == :first
        assert Dialect.nulls_position(dialect, :desc_nulls_first) == :first
        assert Dialect.nulls_position(dialect, :asc_nulls_last) == :last
        assert Dialect.nulls_position(dialect, :desc_nulls_last) == :last
      end
    end
  end

  describe "cursor pagination over a nullable column" do
    test "keeps NULL rows when they sort last" do
      where = cursor_where(PostgresRepo, :asc, 7)

      assert where =~ "p0.age > type(^7, p0.age)"
      assert where =~ "is_nil(p0.age)"

      assert cursor_where(MyXQLRepo, :asc_nulls_last, 7) == where
    end

    test "leaves NULL rows behind when they sort first" do
      assert cursor_where(MyXQLRepo, :asc, 7) ==
               "p0.age > type(^7, p0.age)"

      assert cursor_where(PostgresRepo, :asc_nulls_first, 7) ==
               cursor_where(MyXQLRepo, :asc, 7)
    end

    test "pages forward from a NULL cursor" do
      assert cursor_where(PostgresRepo, :asc, nil) == "false"

      assert cursor_where(MyXQLRepo, :asc, nil) =~ "is_nil(p0.age)"
      refute cursor_where(MyXQLRepo, :asc, nil) =~ ">"

      assert cursor_where(PostgresRepo, :asc_nulls_first, nil) ==
               cursor_where(MyXQLRepo, :asc, nil)
    end

    test "uses the next order field to separate rows that share a NULL" do
      flop = %Flop{
        first: 1,
        after: "cursor",
        decoded_cursor: %{age: nil, name: "Ada"},
        order_by: [:age, :name],
        order_directions: [:asc, :asc]
      }

      where =
        MyApp.Pet
        |> Flop.query(flop, for: MyApp.Pet, repo: PostgresRepo)
        |> cursor_where_inspect()

      assert where =~ "is_nil(p0.age)"
      assert where =~ "p0.name > type(^\"Ada\", p0.name)"
    end

    test "applies the same comparison to a join field" do
      flop = %Flop{
        first: 1,
        after: "cursor",
        decoded_cursor: %{owner_age: 4},
        order_by: [:owner_age],
        order_directions: [:asc]
      }

      query =
        Ecto.Query.from(p in MyApp.Pet,
          left_join: o in Ecto.Query.assoc(p, :owner),
          as: :owner
        )

      where =
        query
        |> Flop.query(flop, for: MyApp.Pet, repo: PostgresRepo)
        |> cursor_where_inspect()

      assert where =~ "age > type(^4,"
      assert where =~ "is_nil("
    end
  end

  defp cursor_where(repo, direction, value) do
    flop = %Flop{
      first: 1,
      after: "cursor",
      decoded_cursor: %{age: value},
      order_by: [:age],
      order_directions: [direction]
    }

    MyApp.Pet
    |> Flop.query(flop, for: MyApp.Pet, repo: repo)
    |> cursor_where_inspect()
  end

  defp cursor_where_inspect(query) do
    query
    |> inspect()
    |> String.split("where: ")
    |> List.last()
    |> String.split(", order_by:")
    |> List.first()
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
