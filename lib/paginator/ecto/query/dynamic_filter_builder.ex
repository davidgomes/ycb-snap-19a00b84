defmodule Paginator.Ecto.Query.DynamicFilterBuilder do
  @moduledoc false

  alias Paginator.Ecto.Query.{AscNullsFirst, AscNullsLast, DescNullsFirst, DescNullsLast}

  @type args :: %{
          sort_order: atom(),
          direction: :after | :before,
          value: any(),
          entity_position: non_neg_integer(),
          column: atom(),
          next_filters: %Ecto.Query.DynamicExpr{} | true
        }

  @doc """
  Builds the dynamic filter for a single cursor field.

  `next_filters` holds the filter built for the remaining cursor fields, used to
  break ties when the value of this field equals the cursor value. It is `true`
  when this is the last cursor field.
  """
  @callback build_dynamic_filter(args()) :: %Ecto.Query.DynamicExpr{}

  # `:asc` and `:desc` follow the Postgres defaults for null values.
  @dispatch_table %{
    asc: AscNullsLast,
    asc_nulls_last: AscNullsLast,
    asc_nulls_first: AscNullsFirst,
    desc: DescNullsFirst,
    desc_nulls_first: DescNullsFirst,
    desc_nulls_last: DescNullsLast
  }

  @spec build!(args()) :: %Ecto.Query.DynamicExpr{}
  def build!(%{sort_order: sort_order} = args) do
    case Map.fetch(@dispatch_table, sort_order) do
      {:ok, module} ->
        module.build_dynamic_filter(args)

      :error ->
        raise(
          "Invalid sorting value :#{sort_order}, please use one of " <>
            Enum.map_join(Map.keys(@dispatch_table), ", ", &inspect/1)
        )
    end
  end

  @spec raise_unstable_sort_order!() :: no_return()
  def raise_unstable_sort_order! do
    raise(
      "Unstable sort order: nullable columns can't be used as the last term of `:cursor_fields`"
    )
  end
end
