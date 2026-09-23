defmodule MyApp.CustomFieldPet do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Query

  alias MyApp.Owner

  @derive {
    Flop.Schema,
    filterable: [
      :age_score,
      :owner_age_score,
      :pet_name,
      :pet_tags,
      :filtered_age_score
    ],
    sortable: [:age_score, :owner_age_score],
    adapter_opts: [
      custom_fields: [
        age_score: [
          field_dynamic:
            {__MODULE__, :age_score_dynamic,
             [factor: 2, compile_only: :available]},
          ecto_type: :integer
        ],
        owner_age_score: [
          field_dynamic: {__MODULE__, :owner_age_score_dynamic, []},
          bindings: [:owner],
          ecto_type: :integer
        ],
        pet_name: [
          field_dynamic: {__MODULE__, :name_dynamic, []},
          ecto_type: :string
        ],
        pet_tags: [
          field_dynamic: {__MODULE__, :tags_dynamic, []},
          ecto_type: {:array, :string}
        ],
        filtered_age_score: [
          filter: {__MODULE__, :filtered_age_score_filter, []},
          field_dynamic: {__MODULE__, :age_score_dynamic, [factor: 2]},
          ecto_type: :integer
        ]
      ]
    ]
  }

  schema "pets" do
    field :age, :integer
    field :name, :string
    field :tags, {:array, :string}
    belongs_to :owner, Owner
  end

  def age_score_dynamic(opts) do
    if test_pid = opts[:test_pid] do
      send(test_pid, {:age_score_dynamic_opts, opts})
    end

    factor = Keyword.fetch!(opts, :factor)
    dynamic([pet], fragment("? * ?", pet.age, ^factor))
  end

  def owner_age_score_dynamic(_opts) do
    dynamic([owner: owner], owner.age)
  end

  def name_dynamic(_opts) do
    dynamic([pet], pet.name)
  end

  def tags_dynamic(_opts) do
    dynamic([pet], pet.tags)
  end

  def filtered_age_score_filter(query, %Flop.Filter{} = filter, _opts) do
    send(self(), {:filtered_age_score_filter, filter})
    query
  end
end
