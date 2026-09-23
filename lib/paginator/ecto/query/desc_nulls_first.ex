defmodule Paginator.Ecto.Query.DescNullsFirst do
  @moduledoc false

  @behaviour Paginator.Ecto.Query.DynamicFilterBuilder

  import Ecto.Query

  alias Paginator.Ecto.Query.DynamicFilterBuilder

  @impl DynamicFilterBuilder
  def build_dynamic_filter(%{value: nil, next_filters: true}) do
    DynamicFilterBuilder.raise_unstable_sort_order!()
  end

  def build_dynamic_filter(%{direction: :after, value: nil} = args) do
    dynamic(
      [{q, args.entity_position}],
      (is_nil(field(q, ^args.column)) and ^args.next_filters) or
        not is_nil(field(q, ^args.column))
    )
  end

  def build_dynamic_filter(%{direction: :after, next_filters: true} = args) do
    dynamic(
      [{q, args.entity_position}],
      field(q, ^args.column) < ^args.value
    )
  end

  def build_dynamic_filter(%{direction: :after} = args) do
    dynamic(
      [{q, args.entity_position}],
      (field(q, ^args.column) == ^args.value and ^args.next_filters) or
        field(q, ^args.column) < ^args.value
    )
  end

  def build_dynamic_filter(%{direction: :before, value: nil} = args) do
    dynamic(
      [{q, args.entity_position}],
      is_nil(field(q, ^args.column)) and ^args.next_filters
    )
  end

  def build_dynamic_filter(%{direction: :before, next_filters: true} = args) do
    dynamic(
      [{q, args.entity_position}],
      field(q, ^args.column) > ^args.value or is_nil(field(q, ^args.column))
    )
  end

  def build_dynamic_filter(%{direction: :before} = args) do
    dynamic(
      [{q, args.entity_position}],
      (field(q, ^args.column) == ^args.value and ^args.next_filters) or
        field(q, ^args.column) > ^args.value or
        is_nil(field(q, ^args.column))
    )
  end
end
