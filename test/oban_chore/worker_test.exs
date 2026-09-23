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
    use ObanChore.Worker, fields: []

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
      name: "Temporal Chore",
      fields: [
        amount: [type: :float],
        run_on: [type: :date],
        run_at: [type: :time],
        starts_at: [type: :utc_datetime]
      ]

    @impl Oban.Worker
    def perform(_), do: :ok
  end

  test "exposes the module and declared fields in __chore_info__" do
    info = MyTestChore.__chore_info__()

    assert info.module == MyTestChore
    assert info.name == "My Test Chore"
    assert info.fields == [user_id: [type: :integer, required: true], age: [type: :integer]]
  end

  test "defaults the chore name to the module name" do
    assert UnnamedWorker.__chore_info__().name == "ObanChore.WorkerTest.UnnamedWorker"
  end

  test "flags workers that define their own unique options" do
    assert UniqueWorker.__chore_info__().unique
    refute MyTestChore.__chore_info__().unique
  end

  test "passes Oban options through to Oban.Worker" do
    changes = UniqueWorker.new(%{user_id: 1}).changes

    assert changes.worker == "ObanChore.WorkerTest.UniqueWorker"
    assert changes.queue == "operational"
    assert changes.max_attempts == 5
    assert changes.unique.period == 60
  end

  test "casts float, date, time and datetime fields from form input" do
    params = %{
      "amount" => "9.5",
      "run_on" => "2024-05-06",
      "run_at" => "13:45",
      "starts_at" => "2024-05-06T13:45"
    }

    changeset = TemporalWorker.changeset(params)

    assert changeset.valid?

    assert changeset.changes == %{
             amount: 9.5,
             run_on: ~D[2024-05-06],
             run_at: ~T[13:45:00],
             starts_at: ~U[2024-05-06 13:45:00Z]
           }
  end

  test "fields are optional unless marked as required" do
    assert ComprehensiveWorker.changeset(%{}).valid?
  end

  test "reports cast errors without also flagging required fields as blank" do
    changeset = MyTestChore.changeset(%{"user_id" => "abc"})

    refute changeset.valid?
    assert errors_on(changeset).user_id == ["is invalid"]
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
