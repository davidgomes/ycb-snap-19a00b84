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

  @default_field_ast quote(do: field(r, ^var!(field)))

  def op_config(op), do: op_config(op, @default_field_ast, true)
  def op_config(op, ilike?) when is_boolean(ilike?), do: op_config(op, @default_field_ast, ilike?)
  def op_config(op, field_ast), do: op_config(op, field_ast, true)

  # The third argument says whether the repo adapter supports ILIKE. If it
  # doesn't, ILIKE is replaced with LIKE. See Flop.Adapter.Ecto.Dialect.
  def op_config(:=~, field_ast, false), do: op_config(:like, field_ast)
  def op_config(:ilike, field_ast, false), do: op_config(:like, field_ast)
  def op_config(:not_ilike, field_ast, false), do: op_config(:not_like, field_ast)
  def op_config(:ilike_and, field_ast, false), do: op_config(:like_and, field_ast)
  def op_config(:ilike_or, field_ast, false), do: op_config(:like_or, field_ast)

  def op_config(:starts_with, field_ast, false) do
    fragment = like_fragment(field_ast, quote(do: ^var!(value)))
    {fragment, prelude(:add_wildcard_suffix), nil}
  end

  def op_config(:ends_with, field_ast, false) do
    fragment = like_fragment(field_ast, quote(do: ^var!(value)))
    {fragment, prelude(:add_wildcard_prefix), nil}
  end

  def op_config(op, field_ast, _ilike?), do: op_config(op, field_ast)

  def op_config(:==, field_ast) do
    fragment =
      quote do
        unquote(field_ast) == ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:!=, field_ast) do
    fragment =
      quote do
        unquote(field_ast) != ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:>=, field_ast) do
    fragment =
      quote do
        unquote(field_ast) >= ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:<=, field_ast) do
    fragment =
      quote do
        unquote(field_ast) <= ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:>, field_ast) do
    fragment =
      quote do
        unquote(field_ast) > ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:<, field_ast) do
    fragment =
      quote do
        unquote(field_ast) < ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:in, field_ast) do
    fragment =
      quote do
        unquote(field_ast) in ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:contains, field_ast) do
    fragment =
      quote do
        ^var!(value) in unquote(field_ast)
      end

    {fragment, nil, nil}
  end

  def op_config(:not_contains, field_ast) do
    fragment =
      quote do
        ^var!(value) not in unquote(field_ast)
      end

    {fragment, nil, nil}
  end

  def op_config(:like, field_ast) do
    fragment = like_fragment(field_ast, quote(do: ^var!(value)))
    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:not_like, field_ast) do
    fragment =
      quote do
        not unquote(like_fragment(field_ast, quote(do: ^var!(value))))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:=~, field_ast), do: op_config(:ilike, field_ast)

  def op_config(:ilike, field_ast) do
    fragment =
      quote do
        ilike(unquote(field_ast), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:not_ilike, field_ast) do
    fragment =
      quote do
        not ilike(unquote(field_ast), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:not_in, field_ast) do
    fragment =
      quote do
        unquote(field_ast) not in ^var!(processed_value) and
          not (^var!(reject_nil?) and is_nil(unquote(field_ast)))
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

  def op_config(:like_and, field_ast) do
    fragment = like_fragment(field_ast, quote(do: ^substring))
    combinator = :and
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:like_or, field_ast) do
    fragment = like_fragment(field_ast, quote(do: ^substring))
    combinator = :or
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:ilike_and, field_ast) do
    fragment =
      quote do
        ilike(unquote(field_ast), ^substring)
      end

    combinator = :and
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:ilike_or, field_ast) do
    fragment =
      quote do
        ilike(unquote(field_ast), ^substring)
      end

    combinator = :or
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:starts_with, field_ast) do
    fragment =
      quote do
        ilike(unquote(field_ast), ^var!(value))
      end

    prelude = prelude(:add_wildcard_suffix)
    {fragment, prelude, nil}
  end

  def op_config(:ends_with, field_ast) do
    fragment =
      quote do
        ilike(unquote(field_ast), ^var!(value))
      end

    prelude = prelude(:add_wildcard_prefix)
    {fragment, prelude, nil}
  end

  # The escape character must be bound rather than written into the fragment
  # because no literal works everywhere. MySQL reads '\' as an incomplete string
  # escape, SQLite and Postgres read '\\' as two characters.
  defp like_fragment(field_ast, pattern) do
    quote do
      fragment(
        "? LIKE ? ESCAPE ?",
        unquote(field_ast),
        unquote(pattern),
        ^"\\"
      )
    end
  end

  defmacro empty(type, field_ast \\ quote(do: field(r, ^var!(field))))

  defmacro empty(:array, field_ast) do
    quote do
      is_nil(unquote(field_ast)) or
        unquote(field_ast) == type(^[], ^var!(ecto_type))
    end
  end

  # for adapters that store an array as a JSON column
  defmacro empty(:json_array, field_ast) do
    quote do
      is_nil(unquote(field_ast)) or
        fragment("JSON_LENGTH(?) = 0", unquote(field_ast))
    end
  end

  defmacro empty(:map, field_ast) do
    quote do
      is_nil(unquote(field_ast)) or
        unquote(field_ast) == type(^%{}, ^var!(ecto_type))
    end
  end

  defmacro empty(:other, field_ast) do
    quote do
      is_nil(unquote(field_ast))
    end
  end

  defmacro json_contains(field_ast \\ quote(do: field(r, ^var!(field)))) do
    quote do
      fragment(
        "JSON_CONTAINS(?, ?)",
        unquote(field_ast),
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
