defmodule Paginator.Ecto.Query.DescNullsLast do
  @behaviour Paginator.Ecto.Query.DynamicFilterBuilder

  import Ecto.Query

  alias Paginator.Ecto.Query.FieldOrExpression

  @impl Paginator.Ecto.Query.DynamicFilterBuilder
  def build_dynamic_filter(%{direction: :before, value: nil, next_filters: true}) do
    raise("unstable sort order: nullable columns can't be used as the last term")
  end

  def build_dynamic_filter(args = %{direction: :before, value: nil}) do
    column = FieldOrExpression.build!(args)

    dynamic((is_nil(^column) and ^args.next_filters) or not is_nil(^column))
  end

  def build_dynamic_filter(args = %{direction: :before, next_filters: true}) do
    column = FieldOrExpression.build!(args)

    dynamic(^column > ^args.value)
  end

  def build_dynamic_filter(args = %{direction: :before}) do
    column = FieldOrExpression.build!(args)

    dynamic((^column == ^args.value and ^args.next_filters) or ^column > ^args.value)
  end

  def build_dynamic_filter(%{direction: :after, value: nil, next_filters: true}) do
    raise("unstable sort order: nullable columns can't be used as the last term")
  end

  def build_dynamic_filter(args = %{direction: :after, value: nil}) do
    column = FieldOrExpression.build!(args)

    dynamic(is_nil(^column) and ^args.next_filters)
  end

  def build_dynamic_filter(args = %{direction: :after, next_filters: true}) do
    column = FieldOrExpression.build!(args)

    dynamic(^column < ^args.value or is_nil(^column))
  end

  def build_dynamic_filter(args = %{direction: :after}) do
    column = FieldOrExpression.build!(args)

    dynamic(
      (^column == ^args.value and ^args.next_filters) or
        ^column < ^args.value or
        is_nil(^column)
    )
  end
end
