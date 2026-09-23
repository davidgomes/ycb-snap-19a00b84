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

  # The source says what an operator is applied to: `:column` is the `field`
  # on the binding `r`, `:dynamic` is the dynamic expression `field_dynamic`
  # returned by the field_dynamic function of a custom field.
  defp field_ref(:column), do: quote(do: field(r, ^var!(field)))
  defp field_ref(:dynamic), do: quote(do: ^var!(field_dynamic))

  # The second argument says whether the repo adapter supports ILIKE. If it
  # doesn't, ILIKE is replaced with LIKE. See Flop.Adapter.Ecto.Dialect.
  def op_config(:=~, false, src), do: op_config(:like, src)
  def op_config(:ilike, false, src), do: op_config(:like, src)
  def op_config(:not_ilike, false, src), do: op_config(:not_like, src)
  def op_config(:ilike_and, false, src), do: op_config(:like_and, src)
  def op_config(:ilike_or, false, src), do: op_config(:like_or, src)

  def op_config(:starts_with, false, src) do
    fragment = like_fragment(quote(do: ^var!(value)), src)
    {fragment, prelude(:add_wildcard_suffix), nil}
  end

  def op_config(:ends_with, false, src) do
    fragment = like_fragment(quote(do: ^var!(value)), src)
    {fragment, prelude(:add_wildcard_prefix), nil}
  end

  def op_config(op, _ilike?, src), do: op_config(op, src)

  def op_config(:==, src) do
    fragment =
      quote do
        unquote(field_ref(src)) == ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:!=, src) do
    fragment =
      quote do
        unquote(field_ref(src)) != ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:>=, src) do
    fragment =
      quote do
        unquote(field_ref(src)) >= ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:<=, src) do
    fragment =
      quote do
        unquote(field_ref(src)) <= ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:>, src) do
    fragment =
      quote do
        unquote(field_ref(src)) > ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:<, src) do
    fragment =
      quote do
        unquote(field_ref(src)) < ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:in, src) do
    fragment =
      quote do
        unquote(field_ref(src)) in ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:contains, src) do
    fragment =
      quote do
        ^var!(value) in unquote(field_ref(src))
      end

    {fragment, nil, nil}
  end

  def op_config(:not_contains, src) do
    fragment =
      quote do
        ^var!(value) not in unquote(field_ref(src))
      end

    {fragment, nil, nil}
  end

  def op_config(:like, src) do
    fragment = like_fragment(quote(do: ^var!(value)), src)
    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:not_like, src) do
    fragment =
      quote do
        not unquote(like_fragment(quote(do: ^var!(value)), src))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:=~, src) do
    fragment =
      quote do
        ilike(unquote(field_ref(src)), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:ilike, src) do
    fragment =
      quote do
        ilike(unquote(field_ref(src)), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:not_ilike, src) do
    fragment =
      quote do
        not ilike(unquote(field_ref(src)), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:not_in, src) do
    fragment =
      quote do
        unquote(field_ref(src)) not in ^var!(processed_value) and
          not (^var!(reject_nil?) and is_nil(unquote(field_ref(src))))
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

  def op_config(:like_and, src) do
    fragment = like_fragment(quote(do: ^substring), src)
    combinator = :and
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:like_or, src) do
    fragment = like_fragment(quote(do: ^substring), src)
    combinator = :or
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:ilike_and, src) do
    fragment =
      quote do
        ilike(unquote(field_ref(src)), ^substring)
      end

    combinator = :and
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:ilike_or, src) do
    fragment =
      quote do
        ilike(unquote(field_ref(src)), ^substring)
      end

    combinator = :or
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:starts_with, src) do
    fragment =
      quote do
        ilike(unquote(field_ref(src)), ^var!(value))
      end

    prelude = prelude(:add_wildcard_suffix)
    {fragment, prelude, nil}
  end

  def op_config(:ends_with, src) do
    fragment =
      quote do
        ilike(unquote(field_ref(src)), ^var!(value))
      end

    prelude = prelude(:add_wildcard_prefix)
    {fragment, prelude, nil}
  end

  # The escape character must be bound rather than written into the fragment
  # because no literal works everywhere. MySQL reads '\' as an incomplete string
  # escape, SQLite and Postgres read '\\' as two characters.
  defp like_fragment(pattern, src) do
    quote do
      fragment(
        "? LIKE ? ESCAPE ?",
        unquote(field_ref(src)),
        unquote(pattern),
        ^"\\"
      )
    end
  end

  defmacro empty(kind, src \\ :column)

  defmacro empty(kind, src) when kind in [:array, :map] do
    quote do
      is_nil(unquote(field_ref(src))) or
        unquote(field_ref(src)) == unquote(empty_value(kind, src))
    end
  end

  # for adapters that store an array as a JSON column
  defmacro empty(:json_array, src) do
    quote do
      is_nil(unquote(field_ref(src))) or
        fragment("JSON_LENGTH(?) = 0", unquote(field_ref(src)))
    end
  end

  defmacro empty(:other, src) do
    quote do
      is_nil(unquote(field_ref(src)))
    end
  end

  # Ecto cannot compare an interpolated dynamic with type/2 if the type is
  # interpolated as well, so the caller has to bind the typed empty value to
  # `empty_value` as a separate dynamic.
  defp empty_value(:array, :column), do: quote(do: type(^[], ^var!(ecto_type)))
  defp empty_value(:map, :column), do: quote(do: type(^%{}, ^var!(ecto_type)))
  defp empty_value(_, :dynamic), do: quote(do: ^var!(empty_value))

  defmacro json_contains(src \\ :column) do
    quote do
      fragment(
        "JSON_CONTAINS(?, ?)",
        unquote(field_ref(src)),
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
