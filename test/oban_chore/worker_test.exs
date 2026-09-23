defmodule ObanChore.WorkerTest do
  use ExUnit.Case, async: true
  import Ecto.Changeset

  defmodule MyTestChore do
    use ObanChore.Worker,
      name: "My Test Chore",
      queue: :default,
      fields: [
        user_id: [type: :integer, required: true],
        age: [type: :integer]
      ]

    @impl ObanChore.Worker
    def custom_changeset(changeset) do
      validate_number(changeset, :age, greater_than: 18)
    end

    @impl Oban.Worker
    def perform(%Oban.Job{}), do: :ok
  end

  defmodule ComprehensiveWorker do
    use ObanChore.Worker,
      name: "All Types Chore",
      fields: [
        # Native types
        my_string: [type: :string],
        my_int: [type: :integer],
        my_bool: [type: :boolean],
        # Mapped types
        my_text: [type: :textarea],
        my_select: [type: :select, options: ["Option 1", "Option 2"]],
        my_checkbox: [type: :checkbox]
      ]

    @impl Oban.Worker
    def perform(_), do: :ok
  end

  defmodule DescriptiveWorker do
    use ObanChore.Worker,
      name: "Descriptive Chore",
      description: "This chore has a helpful description.",
      fields: []

    @impl Oban.Worker
    def perform(_), do: :ok
  end

  defmodule UnnamedWorker do
    use ObanChore.Worker, fields: [note: [type: :string, label: "Note"]]

    @impl Oban.Worker
    def perform(_), do: :ok
  end

  defmodule UniqueWorker do
    use ObanChore.Worker,
      name: "Unique Chore",
      queue: :operational,
      max_attempts: 5,
      unique: [period: 60],
      fields: [user_id: [type: :integer, required: true]]

    @impl Oban.Worker
    def perform(_), do: :ok
  end

  defmodule TemporalWorker do
    use ObanChore.Worker,
      fields: [
        on: [type: :date],
        at: [type: :time],
        run_at: [type: :utc_datetime],
        ratio: [type: :float]
      ]

    @impl Oban.Worker
    def perform(_), do: :ok
  end

  test "exposes the chore metadata in __chore_info__" do
    assert MyTestChore.__chore_info__() == %{
             module: MyTestChore,
             name: "My Test Chore",
             description: nil,
             fields: [
               user_id: [type: :integer, required: true],
               age: [type: :integer]
             ],
             unique: false
           }
  end

  test "defaults the chore name to the module name" do
    assert UnnamedWorker.__chore_info__().name == "ObanChore.WorkerTest.UnnamedWorker"
  end

  test "flags workers that define their own unique options" do
    assert UniqueWorker.__chore_info__().unique
    refute MyTestChore.__chore_info__().unique
  end

  test "passes standard Oban options through to Oban.Worker" do
    opts = UniqueWorker.__opts__()

    assert opts[:queue] == :operational
    assert opts[:max_attempts] == 5
    assert opts[:unique] == [period: 60]
    refute Keyword.has_key?(opts, :fields)
    refute Keyword.has_key?(opts, :name)

    changeset = UniqueWorker.new(%{user_id: 1})
    assert changeset.changes.worker == "ObanChore.WorkerTest.UniqueWorker"
    assert changeset.changes.queue == "operational"
    assert changeset.changes.args == %{user_id: 1}
  end

  test "casts date, time, datetime and float fields" do
    changeset =
      TemporalWorker.changeset(%{
        "on" => "2024-05-01",
        "at" => "13:45:00",
        "run_at" => "2024-05-01T13:45:00Z",
        "ratio" => "0.5"
      })

    assert changeset.valid?
    assert changeset.changes.on == ~D[2024-05-01]
    assert changeset.changes.at == ~T[13:45:00]
    assert changeset.changes.run_at == ~U[2024-05-01 13:45:00Z]
    assert changeset.changes.ratio == 0.5
  end

  test "ignores params that are not declared as fields" do
    changeset = MyTestChore.changeset(%{"user_id" => "1", "unexpected" => "value"})

    assert changeset.valid?
    assert changeset.changes == %{user_id: 1}
  end

  test "reports cast errors on required fields without a blank error" do
    changeset = MyTestChore.changeset(%{"user_id" => "not-a-number"})

    refute changeset.valid?
    assert errors_on(changeset).user_id == ["is invalid"]
  end

  test "changeset/0 validates required fields against empty params" do
    changeset = MyTestChore.changeset()

    refute changeset.valid?
    assert errors_on(changeset) == %{user_id: ["can't be blank"]}
  end

  test "captures description in __chore_info__" do
    info = DescriptiveWorker.__chore_info__()
    assert info.description == "This chore has a helpful description."

    # Verify fallback for workers without description
    info = MyTestChore.__chore_info__()
    assert info.description == nil
  end

  test "correctly maps UI types to Ecto types and casts them" do
    params = %{
      "my_string" => "hello",
      "my_int" => "42",
      "my_bool" => "true",
      "my_text" => "some long text",
      "my_select" => "option1",
      "my_checkbox" => "true"
    }

    changeset = ComprehensiveWorker.changeset(params)
    assert changeset.valid?

    # Verify values and their types
    assert changeset.changes.my_string == "hello"
    assert changeset.changes.my_int == 42
    assert changeset.changes.my_bool == true
    assert changeset.changes.my_text == "some long text"
    assert changeset.changes.my_select == "option1"
    assert changeset.changes.my_checkbox == true
  end

  test "injects changeset/1 and custom_changeset/1" do
    # Valid data
    changeset = MyTestChore.changeset(%{"user_id" => "1", "age" => "25"})
    assert changeset.valid?
    assert changeset.changes.user_id == 1
    assert changeset.changes.age == 25

    # Missing required field
    changeset = MyTestChore.changeset(%{"age" => "25"})
    refute changeset.valid?
    assert "can't be blank" in errors_on(changeset).user_id

    # Custom validation failure
    changeset = MyTestChore.changeset(%{"user_id" => "1", "age" => "15"})
    refute changeset.valid?
    assert "must be greater than 18" in errors_on(changeset).age
  end

  test "raises on missing field type" do
    assert_raise ArgumentError, ~r/missing :type for field :bad_field/, fn ->
      defmodule MissingTypeChore do
        use ObanChore.Worker,
          name: "Missing Type",
          fields: [bad_field: []]
      end
    end
  end

  test "raises on invalid field type" do
    assert_raise ArgumentError, ~r/invalid type :invalid_type/, fn ->
      defmodule InvalidChore do
        use ObanChore.Worker,
          name: "Invalid",
          fields: [bad_field: [type: :invalid_type]]
      end
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
