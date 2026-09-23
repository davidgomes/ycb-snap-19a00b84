defmodule Flop.Adapter.Ecto.Operators do
  @moduledoc false

  import Ecto.Query

  alias Flop.Adapter.Ecto.Dialect

  defmacro build_dynamic(fragment, binding?, _combinator = nil) do
    binding_arg = binding_arg(binding?)

    quote do
      dynamic(unquote(binding_arg), unquote(fragment))
    end
  end

  defmacro build_dynamic(fragment, binding?, :and) do
    binding_arg = binding_arg(binding?)

    quote do
      filter_condition =
        Enum.reduce(var!(value), true, fn substring, dynamic ->
          dynamic(unquote(binding_arg), ^dynamic and unquote(fragment))
        end)

      dynamic(unquote(binding_arg), ^filter_condition)
    end
  end

  defmacro build_dynamic(fragment, binding?, :or) do
    binding_arg = binding_arg(binding?)

    quote do
      filter_condition =
        Enum.reduce(var!(value), false, fn substring, dynamic ->
          dynamic(unquote(binding_arg), ^dynamic or unquote(fragment))
        end)

      dynamic(unquote(binding_arg), ^filter_condition)
    end
  end

  def reduce_dynamic(:and, values, inner_func) do
    Enum.reduce(values, true, fn value, dynamic ->
      dynamic([r], ^dynamic and ^inner_func.(value))
    end)
  end

  def reduce_dynamic(:or, values, inner_func) do
    Enum.reduce(values, false, fn value, dynamic ->
      dynamic([r], ^dynamic or ^inner_func.(value))
    end)
  end

  defp binding_arg(true) do
    quote do
      [{^var!(binding), r}]
    end
  end

  defp binding_arg(false) do
    quote do
      [r]
    end
  end

  # The second argument says whether the repo adapter supports ILIKE. If it
  # doesn't, ILIKE is replaced with LIKE. See Flop.Adapter.Ecto.Dialect.
  #
  # The third argument selects the column expression: `:field` reads
  # `field(r, ^field)`, `:expr` interpolates a dynamic expression from
  # `field_dynamic`.
  def op_config(op), do: op_config(op, true, :field)

  def op_config(:=~, false), do: op_config(:like)
  def op_config(:ilike, false), do: op_config(:like)
  def op_config(:not_ilike, false), do: op_config(:not_like)
  def op_config(:ilike_and, false), do: op_config(:like_and)
  def op_config(:ilike_or, false), do: op_config(:like_or)

  def op_config(:starts_with, false) do
    op_config(:starts_with, false, :field)
  end

  def op_config(:ends_with, false) do
    op_config(:ends_with, false, :field)
  end

  def op_config(op, ilike?) when is_boolean(ilike?), do: op_config(op, ilike?, :field)

  def op_config(:=~, false, source), do: op_config(:like, true, source)
  def op_config(:ilike, false, source), do: op_config(:like, true, source)
  def op_config(:not_ilike, false, source), do: op_config(:not_like, true, source)
  def op_config(:ilike_and, false, source), do: op_config(:like_and, true, source)
  def op_config(:ilike_or, false, source), do: op_config(:like_or, true, source)

  def op_config(:starts_with, false, source) do
    fragment = like_fragment(quote(do: ^var!(value)), source)
    {fragment, prelude(:add_wildcard_suffix), nil}
  end

  def op_config(:ends_with, false, source) do
    fragment = like_fragment(quote(do: ^var!(value)), source)
    {fragment, prelude(:add_wildcard_prefix), nil}
  end

  def op_config(op, _ilike?, source), do: op_config_source(op, source)

  defp op_config_source(:==, source) do
    column = column(source)

    fragment =
      quote do
        unquote(column) == ^var!(value)
      end

    {fragment, nil, nil}
  end

  defp op_config_source(:!=, source) do
    column = column(source)

    fragment =
      quote do
        unquote(column) != ^var!(value)
      end

    {fragment, nil, nil}
  end

  defp op_config_source(:>=, source) do
    column = column(source)

    fragment =
      quote do
        unquote(column) >= ^var!(value)
      end

    {fragment, nil, nil}
  end

  defp op_config_source(:<=, source) do
    column = column(source)

    fragment =
      quote do
        unquote(column) <= ^var!(value)
      end

    {fragment, nil, nil}
  end

  defp op_config_source(:>, source) do
    column = column(source)

    fragment =
      quote do
        unquote(column) > ^var!(value)
      end

    {fragment, nil, nil}
  end

  defp op_config_source(:<, source) do
    column = column(source)

    fragment =
      quote do
        unquote(column) < ^var!(value)
      end

    {fragment, nil, nil}
  end

  defp op_config_source(:in, source) do
    column = column(source)

    fragment =
      quote do
        unquote(column) in ^var!(value)
      end

    {fragment, nil, nil}
  end

  defp op_config_source(:contains, source) do
    column = column(source)

    fragment =
      quote do
        ^var!(value) in unquote(column)
      end

    {fragment, nil, nil}
  end

  defp op_config_source(:not_contains, source) do
    column = column(source)

    fragment =
      quote do
        ^var!(value) not in unquote(column)
      end

    {fragment, nil, nil}
  end

  defp op_config_source(:like, source) do
    fragment = like_fragment(quote(do: ^var!(value)), source)
    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  defp op_config_source(:not_like, source) do
    fragment =
      quote do
        not unquote(like_fragment(quote(do: ^var!(value)), unquote(source)))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  defp op_config_source(:=~, source) do
    column = column(source)

    fragment =
      quote do
        ilike(unquote(column), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  defp op_config_source(:ilike, source) do
    column = column(source)

    fragment =
      quote do
        ilike(unquote(column), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  defp op_config_source(:not_ilike, source) do
    column = column(source)

    fragment =
      quote do
        not ilike(unquote(column), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  defp op_config_source(:not_in, source) do
    column = column(source)

    fragment =
      quote do
        unquote(column) not in ^var!(processed_value) and
          not (^var!(reject_nil?) and is_nil(unquote(column)))
      end

    prelude =
      quote do
        var!(reject_nil?) = nil in var!(value)

        var!(processed_value) =
          if var!(reject_nil?),
            do: Enum.reject(var!(value), &is_nil(&1)),
            else: var!(value)
      end

    {fragment, prelude, nil}
  end

  defp op_config_source(:like_and, source) do
    fragment = like_fragment(quote(do: ^substring), source)
    combinator = :and
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  defp op_config_source(:like_or, source) do
    fragment = like_fragment(quote(do: ^substring), source)
    combinator = :or
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  defp op_config_source(:ilike_and, source) do
    column = column(source)

    fragment =
      quote do
        ilike(unquote(column), ^substring)
      end

    combinator = :and
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  defp op_config_source(:ilike_or, source) do
    column = column(source)

    fragment =
      quote do
        ilike(unquote(column), ^substring)
      end

    combinator = :or
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  defp op_config_source(:starts_with, source) do
    column = column(source)

    fragment =
      quote do
        ilike(unquote(column), ^var!(value))
      end

    prelude = prelude(:add_wildcard_suffix)
    {fragment, prelude, nil}
  end

  defp op_config_source(:ends_with, source) do
    column = column(source)

    fragment =
      quote do
        ilike(unquote(column), ^var!(value))
      end

    prelude = prelude(:add_wildcard_prefix)
    {fragment, prelude, nil}
  end

  defp column(:field) do
    quote do
      field(r, ^var!(field))
    end
  end

  defp column(:expr) do
    quote do
      ^var!(field_expr)
    end
  end

  # The escape character must be bound rather than written into the fragment
  # because no literal works everywhere. MySQL reads '\' as an incomplete string
  # escape, SQLite and Postgres read '\\' as two characters.
  defp like_fragment(pattern, source) do
    column = column(source)

    quote do
      fragment(
        "? LIKE ? ESCAPE ?",
        unquote(column),
        unquote(pattern),
        ^"\\"
      )
    end
  end

  defmacro empty(kind, source \\ :field)

  defmacro empty(:array, source) do
    column = column(source)

    quote do
      is_nil(unquote(column)) or
        unquote(column) == type(^[], ^var!(ecto_type))
    end
  end

  # for adapters that store an array as a JSON column
  defmacro empty(:json_array, source) do
    column = column(source)

    quote do
      is_nil(unquote(column)) or
        fragment("JSON_LENGTH(?) = 0", unquote(column))
    end
  end

  defmacro empty(:map, source) do
    column = column(source)

    quote do
      is_nil(unquote(column)) or
        unquote(column) == type(^%{}, ^var!(ecto_type))
    end
  end

  defmacro empty(:other, source) do
    column = column(source)

    quote do
      is_nil(unquote(column))
    end
  end

  defmacro json_contains(source \\ :field) do
    column = column(source)

    quote do
      fragment(
        "JSON_CONTAINS(?, ?)",
        unquote(column),
        ^[Dialect.dump_array_element(var!(value), var!(ecto_type))]
      )
    end
  end

  defp prelude(:add_wildcard) do
    quote do
      var!(value) = Flop.Misc.add_wildcard(var!(value))
    end
  end

  defp prelude(:add_wildcard_suffix) do
    quote do
      var!(value) = Flop.Misc.add_wildcard_suffix(var!(value))
    end
  end

  defp prelude(:add_wildcard_prefix) do
    quote do
      var!(value) = Flop.Misc.add_wildcard_prefix(var!(value))
    end
  end

  defp prelude(:maybe_split_search_text) do
    quote do
      var!(value) =
        if is_binary(var!(value)) do
          Flop.Misc.split_search_text(var!(value))
        else
          Enum.map(var!(value), &Flop.Misc.add_wildcard/1)
        end
    end
  end
end
