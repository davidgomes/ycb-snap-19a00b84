defmodule ObanChore.WorkerTest do
  use ExUnit.Case, async: true

  defmodule BasicChore do
    use ObanChore.Worker,
      name: "Basic Chore",
      description: "Does basic things",
      fields: [
        user_id: [type: :integer, required: true],
        note: [type: :textarea],
        mode: [type: :select, options: ["a", "b"]],
        dry_run: [type: :checkbox, default: true]
      ],
      queue: :default,
      unique: [period: 60]

    @impl Oban.Worker
    def perform(_), do: :ok
  end

  defmodule UnnamedChore do
    use ObanChore.Worker, fields: [arg: [type: :string]]

    @impl Oban.Worker
    def perform(_), do: :ok
  end

  defmodule CustomChore do
    use ObanChore.Worker, fields: [count: [type: :integer, required: true]]

    @impl Oban.Worker
    def perform(_), do: :ok

    @impl true
    def custom_changeset(changeset) do
      validate_number(changeset, :count, greater_than: 0)
    end
  end

  describe "__chore_info__/0" do
    test "returns chore metadata" do
      info = BasicChore.__chore_info__()

      assert info.module == BasicChore
      assert info.name == "Basic Chore"
      assert info.description == "Does basic things"
      assert info.unique == true
      assert Keyword.keys(info.fields) == [:user_id, :note, :mode, :dry_run]
    end

    test "defaults name to the module name and unique to false" do
      info = UnnamedChore.__chore_info__()

      assert info.name == inspect(UnnamedChore)
      assert info.description == nil
      assert info.unique == false
    end
  end

  test "passes Oban options through to Oban.Worker" do
    assert BasicChore.__opts__()[:queue] == :default
  end

  describe "changeset/1" do
    test "casts UI types to their underlying Ecto types" do
      changeset =
        BasicChore.changeset(%{
          "user_id" => "5",
          "note" => "hi",
          "mode" => "a",
          "dry_run" => "true"
        })

      assert changeset.valid?
      assert changeset.changes == %{user_id: 5, note: "hi", mode: "a", dry_run: true}
    end

    test "validates required fields" do
      changeset = BasicChore.changeset(%{})

      refute changeset.valid?
      assert {_, [validation: :required]} = changeset.errors[:user_id]
    end

    test "does not add a required error on top of a cast error" do
      changeset = BasicChore.changeset(%{"user_id" => "abc"})

      refute changeset.valid?
      assert [{:user_id, {_, opts}}] = changeset.errors
      assert opts[:validation] == :cast
    end

    test "applies custom_changeset/1" do
      refute CustomChore.changeset(%{"count" => "0"}).valid?
      assert CustomChore.changeset(%{"count" => "3"}).valid?
    end
  end

  describe "compile-time validation" do
    test "raises when a field has no type" do
      assert_raise ArgumentError, ~r/missing :type for field :arg/, fn ->
        Code.compile_quoted(
          quote do
            defmodule MissingTypeChore do
              use ObanChore.Worker, fields: [arg: [label: "Arg"]]
            end
          end
        )
      end
    end

    test "raises when a field has an unsupported type" do
      assert_raise ArgumentError, ~r/invalid type :map for field :arg/, fn ->
        Code.compile_quoted(
          quote do
            defmodule InvalidTypeChore do
              use ObanChore.Worker, fields: [arg: [type: :map]]
            end
          end
        )
      end
    end
  end
end
