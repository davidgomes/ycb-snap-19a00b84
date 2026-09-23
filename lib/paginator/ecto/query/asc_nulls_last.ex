defmodule Paginator.Ecto.Query.AscNullsLast do
  @behaviour Paginator.Ecto.Query.DynamicFilterBuilder

  import Ecto.Query

  @impl Paginator.Ecto.Query.DynamicFilterBuilder
  def build_dynamic_filter(%{direction: :after, value: nil, next_filters: true}) do
    raise("unstable sort order: nullable columns can't be used as the last term")
  end

  def build_dynamic_filter(args = %{direction: :after, value: nil}) do
    dynamic(is_nil(^args.column_expr) and ^args.next_filters
    )
  end

  def build_dynamic_filter(args = %{direction: :after, next_filters: true}) do
    dynamic(^args.column_expr > ^args.value or is_nil(^args.column_expr)
    )
  end

  def build_dynamic_filter(args = %{direction: :after}) do
    dynamic((^args.column_expr == ^args.value and ^args.next_filters) or
        ^args.column_expr > ^args.value or
        is_nil(^args.column_expr)
    )
  end

  def build_dynamic_filter(%{direction: :before, value: nil, next_filters: true}) do
    raise("unstable sort order: nullable columns can't be used as the last term")
  end

  def build_dynamic_filter(args = %{direction: :before, value: nil}) do
    dynamic((is_nil(^args.column_expr) and ^args.next_filters) or
        not is_nil(^args.column_expr)
    )
  end

  def build_dynamic_filter(args = %{direction: :before, next_filters: true}) do
    dynamic(^args.column_expr < ^args.value)
  end

  def build_dynamic_filter(args = %{direction: :before}) do
    dynamic((^args.column_expr == ^args.value and ^args.next_filters) or
        ^args.column_expr < ^args.value
    )
  end
end
