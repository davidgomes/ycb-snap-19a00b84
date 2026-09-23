defmodule Paginator.Ecto.Query.DescNullsFirst do
  @behaviour Paginator.Ecto.Query.DynamicFilterBuilder

  import Ecto.Query
  import Paginator.Ecto.Query.FieldOrExpression

  @impl Paginator.Ecto.Query.DynamicFilterBuilder
  def build_dynamic_filter(%{direction: :before, value: nil, next_filters: true}) do
    raise("unstable sort order: nullable columns can't be used as the last term")
  end

  def build_dynamic_filter(args = %{direction: :before, value: nil}) do
    dynamic(^null(args) and ^args.next_filters)
  end

  def build_dynamic_filter(args = %{direction: :before, next_filters: true}) do
    dynamic(^greater(args) or ^null(args))
  end

  def build_dynamic_filter(args = %{direction: :before}) do
    dynamic((^equal(args) and ^args.next_filters) or ^greater(args) or ^null(args))
  end

  def build_dynamic_filter(%{direction: :after, value: nil, next_filters: true}) do
    raise("unstable sort order: nullable columns can't be used as the last term")
  end

  def build_dynamic_filter(args = %{direction: :after, value: nil}) do
    dynamic((^null(args) and ^args.next_filters) or not (^null(args)))
  end

  def build_dynamic_filter(args = %{direction: :after, next_filters: true}) do
    less(args)
  end

  def build_dynamic_filter(args = %{direction: :after}) do
    dynamic((^equal(args) and ^args.next_filters) or ^less(args))
  end
end
