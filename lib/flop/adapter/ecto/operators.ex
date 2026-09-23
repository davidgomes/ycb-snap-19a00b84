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
  # The last argument is the source of the filtered value. See field_expr/1.
  def op_config(:=~, false, source), do: op_config(:like, source)
  def op_config(:ilike, false, source), do: op_config(:like, source)
  def op_config(:not_ilike, false, source), do: op_config(:not_like, source)
  def op_config(:ilike_and, false, source), do: op_config(:like_and, source)
  def op_config(:ilike_or, false, source), do: op_config(:like_or, source)

  def op_config(:starts_with, false, source) do
    fragment = like_fragment(source, quote(do: ^var!(value)))
    {fragment, prelude(:add_wildcard_suffix), nil}
  end

  def op_config(:ends_with, false, source) do
    fragment = like_fragment(source, quote(do: ^var!(value)))
    {fragment, prelude(:add_wildcard_prefix), nil}
  end

  def op_config(op, _ilike?, source), do: op_config(op, source)

  def op_config(:==, source) do
    fragment =
      quote do
        unquote(field_expr(source)) == ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:!=, source) do
    fragment =
      quote do
        unquote(field_expr(source)) != ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:>=, source) do
    fragment =
      quote do
        unquote(field_expr(source)) >= ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:<=, source) do
    fragment =
      quote do
        unquote(field_expr(source)) <= ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:>, source) do
    fragment =
      quote do
        unquote(field_expr(source)) > ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:<, source) do
    fragment =
      quote do
        unquote(field_expr(source)) < ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:in, source) do
    fragment =
      quote do
        unquote(field_expr(source)) in ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:contains, source) do
    fragment =
      quote do
        ^var!(value) in unquote(field_expr(source))
      end

    {fragment, nil, nil}
  end

  def op_config(:not_contains, source) do
    fragment =
      quote do
        ^var!(value) not in unquote(field_expr(source))
      end

    {fragment, nil, nil}
  end

  def op_config(:like, source) do
    fragment = like_fragment(source, quote(do: ^var!(value)))
    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:not_like, source) do
    fragment =
      quote do
        not unquote(like_fragment(source, quote(do: ^var!(value))))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:=~, source) do
    fragment =
      quote do
        ilike(unquote(field_expr(source)), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:ilike, source) do
    fragment =
      quote do
        ilike(unquote(field_expr(source)), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:not_ilike, source) do
    fragment =
      quote do
        not ilike(unquote(field_expr(source)), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:not_in, source) do
    fragment =
      quote do
        unquote(field_expr(source)) not in ^var!(processed_value) and
          not (^var!(reject_nil?) and is_nil(unquote(field_expr(source))))
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

  def op_config(:like_and, source) do
    fragment = like_fragment(source, quote(do: ^substring))
    combinator = :and
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:like_or, source) do
    fragment = like_fragment(source, quote(do: ^substring))
    combinator = :or
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:ilike_and, source) do
    fragment =
      quote do
        ilike(unquote(field_expr(source)), ^substring)
      end

    combinator = :and
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:ilike_or, source) do
    fragment =
      quote do
        ilike(unquote(field_expr(source)), ^substring)
      end

    combinator = :or
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:starts_with, source) do
    fragment =
      quote do
        ilike(unquote(field_expr(source)), ^var!(value))
      end

    prelude = prelude(:add_wildcard_suffix)
    {fragment, prelude, nil}
  end

  def op_config(:ends_with, source) do
    fragment =
      quote do
        ilike(unquote(field_expr(source)), ^var!(value))
      end

    prelude = prelude(:add_wildcard_prefix)
    {fragment, prelude, nil}
  end

  # `:column` is the column `field` of the binding `r`. `:dynamic` is the
  # `field_dynamic` expression of a custom field.
  defp field_expr(:column), do: quote(do: field(r, ^var!(field)))
  defp field_expr(:dynamic), do: quote(do: ^var!(field_dynamic))

  # The escape character must be bound rather than written into the fragment
  # because no literal works everywhere. MySQL reads '\' as an incomplete string
  # escape, SQLite and Postgres read '\\' as two characters.
  defp like_fragment(source, pattern) do
    quote do
      fragment(
        "? LIKE ? ESCAPE ?",
        unquote(field_expr(source)),
        unquote(pattern),
        ^"\\"
      )
    end
  end

  defmacro empty(kind, source \\ :column)

  defmacro empty(:array, source) do
    quote do
      is_nil(unquote(field_expr(source))) or
        unquote(field_expr(source)) == type(^[], ^var!(ecto_type))
    end
  end

  # for adapters that store an array as a JSON column
  defmacro empty(:json_array, source) do
    quote do
      is_nil(unquote(field_expr(source))) or
        fragment("JSON_LENGTH(?) = 0", unquote(field_expr(source)))
    end
  end

  defmacro empty(:map, source) do
    quote do
      is_nil(unquote(field_expr(source))) or
        unquote(field_expr(source)) == type(^%{}, ^var!(ecto_type))
    end
  end

  defmacro empty(:other, source) do
    quote do
      is_nil(unquote(field_expr(source)))
    end
  end

  defmacro json_contains(source \\ :column) do
    quote do
      fragment(
        "JSON_CONTAINS(?, ?)",
        unquote(field_expr(source)),
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
