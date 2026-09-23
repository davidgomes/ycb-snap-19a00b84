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
  # The third argument is the field source: `:column` reads `field(r, ^field)`
  # and `:dynamic` compares an interpolated `field_expr`.
  def op_config(op) when is_atom(op), do: op_config(op, true, :column)

  def op_config(op, ilike?, source \\ :column)

  def op_config(:=~, false, source), do: op_fragment(:like, source)
  def op_config(:ilike, false, source), do: op_fragment(:like, source)
  def op_config(:not_ilike, false, source), do: op_fragment(:not_like, source)
  def op_config(:ilike_and, false, source), do: op_fragment(:like_and, source)
  def op_config(:ilike_or, false, source), do: op_fragment(:like_or, source)

  def op_config(:starts_with, false, source) do
    fragment = like_fragment(quote(do: ^var!(value)), source)
    {fragment, prelude(:add_wildcard_suffix), nil}
  end

  def op_config(:ends_with, false, source) do
    fragment = like_fragment(quote(do: ^var!(value)), source)
    {fragment, prelude(:add_wildcard_prefix), nil}
  end

  def op_config(op, _ilike?, source), do: op_fragment(op, source)

  defp op_fragment(op, source)
       when op in [:==, :!=, :>=, :<=, :>, :<] do
    fragment = {op, [], [field_ref(source), quote(do: ^var!(value))]}
    {fragment, nil, nil}
  end

  defp op_fragment(:in, source) do
    fragment =
      quote do
        unquote(field_ref(source)) in ^var!(value)
      end

    {fragment, nil, nil}
  end

  defp op_fragment(:contains, source) do
    fragment =
      quote do
        ^var!(value) in unquote(field_ref(source))
      end

    {fragment, nil, nil}
  end

  defp op_fragment(:not_contains, source) do
    fragment =
      quote do
        ^var!(value) not in unquote(field_ref(source))
      end

    {fragment, nil, nil}
  end

  defp op_fragment(:like, source) do
    fragment = like_fragment(quote(do: ^var!(value)), source)
    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  defp op_fragment(:not_like, source) do
    fragment =
      quote do
        not unquote(like_fragment(quote(do: ^var!(value)), source))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  defp op_fragment(:ilike, source) do
    fragment =
      quote do
        ilike(unquote(field_ref(source)), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  defp op_fragment(:=~, source), do: op_fragment(:ilike, source)

  defp op_fragment(:not_ilike, source) do
    fragment =
      quote do
        not ilike(unquote(field_ref(source)), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  defp op_fragment(:not_in, source) do
    fragment =
      quote do
        unquote(field_ref(source)) not in ^var!(processed_value) and
          not (^var!(reject_nil?) and is_nil(unquote(field_ref(source))))
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

  defp op_fragment(:like_and, source) do
    fragment = like_fragment(quote(do: ^substring), source)
    combinator = :and
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  defp op_fragment(:like_or, source) do
    fragment = like_fragment(quote(do: ^substring), source)
    combinator = :or
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  defp op_fragment(:ilike_and, source) do
    fragment =
      quote do
        ilike(unquote(field_ref(source)), ^substring)
      end

    combinator = :and
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  defp op_fragment(:ilike_or, source) do
    fragment =
      quote do
        ilike(unquote(field_ref(source)), ^substring)
      end

    combinator = :or
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  defp op_fragment(:starts_with, source) do
    fragment =
      quote do
        ilike(unquote(field_ref(source)), ^var!(value))
      end

    prelude = prelude(:add_wildcard_suffix)
    {fragment, prelude, nil}
  end

  defp op_fragment(:ends_with, source) do
    fragment =
      quote do
        ilike(unquote(field_ref(source)), ^var!(value))
      end

    prelude = prelude(:add_wildcard_prefix)
    {fragment, prelude, nil}
  end

  # `:column` is a schema or join field. `:dynamic` is the expression returned
  # by a custom field's `field_dynamic` function.
  defp field_ref(:column) do
    quote do
      field(r, ^var!(field))
    end
  end

  defp field_ref(:dynamic) do
    quote do
      ^var!(field_expr)
    end
  end

  # The escape character must be bound rather than written into the fragment
  # because no literal works everywhere. MySQL reads '\' as an incomplete string
  # escape, SQLite and Postgres read '\\' as two characters.
  defp like_fragment(pattern, source) do
    quote do
      fragment(
        "? LIKE ? ESCAPE ?",
        unquote(field_ref(source)),
        unquote(pattern),
        ^"\\"
      )
    end
  end

  defmacro empty(:array) do
    quote do
      is_nil(field(r, ^var!(field))) or
        field(r, ^var!(field)) == type(^[], ^var!(ecto_type))
    end
  end

  # for adapters that store an array as a JSON column
  defmacro empty(:json_array) do
    quote do
      is_nil(field(r, ^var!(field))) or
        fragment("JSON_LENGTH(?) = 0", field(r, ^var!(field)))
    end
  end

  defmacro empty(:map) do
    quote do
      is_nil(field(r, ^var!(field))) or
        field(r, ^var!(field)) == type(^%{}, ^var!(ecto_type))
    end
  end

  defmacro empty(:other) do
    quote do
      is_nil(field(r, ^var!(field)))
    end
  end

  defmacro json_contains do
    quote do
      fragment(
        "JSON_CONTAINS(?, ?)",
        field(r, ^var!(field)),
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
