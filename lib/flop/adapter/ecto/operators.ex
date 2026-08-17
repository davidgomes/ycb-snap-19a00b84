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

  defp binding_arg(:expr) do
    quote do
      []
    end
  end

  defp column_field, do: quote(do: field(r, ^var!(field)))
  defp dynamic_field, do: quote(do: ^var!(field_expr))

  # The second argument says whether the repo adapter supports ILIKE. If it
  # doesn't, ILIKE is replaced with LIKE. See Flop.Adapter.Ecto.Dialect.
  def op_config(op), do: do_op_config(op, true, column_field())
  def op_config(op, ilike?), do: do_op_config(op, ilike?, column_field())

  def op_config_dynamic(op), do: do_op_config(op, true, dynamic_field())
  def op_config_dynamic(op, ilike?), do: do_op_config(op, ilike?, dynamic_field())

  defp do_op_config(:=~, false, field), do: do_op_config(:like, true, field)
  defp do_op_config(:ilike, false, field), do: do_op_config(:like, true, field)

  defp do_op_config(:not_ilike, false, field),
    do: do_op_config(:not_like, true, field)

  defp do_op_config(:ilike_and, false, field),
    do: do_op_config(:like_and, true, field)

  defp do_op_config(:ilike_or, false, field),
    do: do_op_config(:like_or, true, field)

  defp do_op_config(:starts_with, false, field) do
    fragment = like_fragment(quote(do: ^var!(value)), field)
    {fragment, prelude(:add_wildcard_suffix), nil}
  end

  defp do_op_config(:ends_with, false, field) do
    fragment = like_fragment(quote(do: ^var!(value)), field)
    {fragment, prelude(:add_wildcard_prefix), nil}
  end

  defp do_op_config(op, _ilike?, field), do: do_op_config(op, field)

  defp do_op_config(:==, field) do
    fragment =
      quote do
        unquote(field) == ^var!(value)
      end

    {fragment, nil, nil}
  end

  defp do_op_config(:!=, field) do
    fragment =
      quote do
        unquote(field) != ^var!(value)
      end

    {fragment, nil, nil}
  end

  defp do_op_config(:>=, field) do
    fragment =
      quote do
        unquote(field) >= ^var!(value)
      end

    {fragment, nil, nil}
  end

  defp do_op_config(:<=, field) do
    fragment =
      quote do
        unquote(field) <= ^var!(value)
      end

    {fragment, nil, nil}
  end

  defp do_op_config(:>, field) do
    fragment =
      quote do
        unquote(field) > ^var!(value)
      end

    {fragment, nil, nil}
  end

  defp do_op_config(:<, field) do
    fragment =
      quote do
        unquote(field) < ^var!(value)
      end

    {fragment, nil, nil}
  end

  defp do_op_config(:in, field) do
    fragment =
      quote do
        unquote(field) in ^var!(value)
      end

    {fragment, nil, nil}
  end

  defp do_op_config(:contains, field) do
    fragment =
      quote do
        ^var!(value) in unquote(field)
      end

    {fragment, nil, nil}
  end

  defp do_op_config(:not_contains, field) do
    fragment =
      quote do
        ^var!(value) not in unquote(field)
      end

    {fragment, nil, nil}
  end

  defp do_op_config(:like, field) do
    fragment = like_fragment(quote(do: ^var!(value)), field)
    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  defp do_op_config(:not_like, field) do
    fragment =
      quote do
        not unquote(like_fragment(quote(do: ^var!(value)), field))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  defp do_op_config(:=~, field) do
    fragment =
      quote do
        ilike(unquote(field), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  defp do_op_config(:ilike, field) do
    fragment =
      quote do
        ilike(unquote(field), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  defp do_op_config(:not_ilike, field) do
    fragment =
      quote do
        not ilike(unquote(field), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  defp do_op_config(:not_in, field) do
    fragment =
      quote do
        unquote(field) not in ^var!(processed_value) and
          not (^var!(reject_nil?) and is_nil(unquote(field)))
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

  defp do_op_config(:like_and, field) do
    fragment = like_fragment(quote(do: ^substring), field)
    combinator = :and
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  defp do_op_config(:like_or, field) do
    fragment = like_fragment(quote(do: ^substring), field)
    combinator = :or
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  defp do_op_config(:ilike_and, field) do
    fragment =
      quote do
        ilike(unquote(field), ^substring)
      end

    combinator = :and
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  defp do_op_config(:ilike_or, field) do
    fragment =
      quote do
        ilike(unquote(field), ^substring)
      end

    combinator = :or
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  defp do_op_config(:starts_with, field) do
    fragment =
      quote do
        ilike(unquote(field), ^var!(value))
      end

    prelude = prelude(:add_wildcard_suffix)
    {fragment, prelude, nil}
  end

  defp do_op_config(:ends_with, field) do
    fragment =
      quote do
        ilike(unquote(field), ^var!(value))
      end

    prelude = prelude(:add_wildcard_prefix)
    {fragment, prelude, nil}
  end

  # The escape character must be bound rather than written into the fragment
  # because no literal works everywhere. MySQL reads '\' as an incomplete string
  # escape, SQLite and Postgres read '\\' as two characters.
  defp like_fragment(pattern, field) do
    quote do
      fragment(
        "? LIKE ? ESCAPE ?",
        unquote(field),
        unquote(pattern),
        ^"\\"
      )
    end
  end

  defmacro empty(:array) do
    empty_ast(:array, quote(do: field(r, ^var!(field))))
  end

  defmacro empty(:json_array) do
    empty_ast(:json_array, quote(do: field(r, ^var!(field))))
  end

  defmacro empty(:map) do
    empty_ast(:map, quote(do: field(r, ^var!(field))))
  end

  defmacro empty(:other) do
    empty_ast(:other, quote(do: field(r, ^var!(field))))
  end

  defmacro empty_dynamic(kind) do
    empty_ast(kind, quote(do: ^var!(field_expr)))
  end

  defp empty_ast(:array, field) do
    quote do
      is_nil(unquote(field)) or
        unquote(field) == type(^[], ^var!(ecto_type))
    end
  end

  # for adapters that store an array as a JSON column
  defp empty_ast(:json_array, field) do
    quote do
      is_nil(unquote(field)) or
        fragment("JSON_LENGTH(?) = 0", unquote(field))
    end
  end

  defp empty_ast(:map, field) do
    quote do
      is_nil(unquote(field)) or
        unquote(field) == type(^%{}, ^var!(ecto_type))
    end
  end

  defp empty_ast(:other, field) do
    quote do
      is_nil(unquote(field))
    end
  end

  defmacro json_contains do
    json_contains_ast(quote(do: field(r, ^var!(field))))
  end

  defmacro json_contains_dynamic do
    json_contains_ast(quote(do: ^var!(field_expr)))
  end

  defp json_contains_ast(field) do
    quote do
      fragment(
        "JSON_CONTAINS(?, ?)",
        unquote(field),
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
