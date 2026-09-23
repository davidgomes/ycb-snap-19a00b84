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
  # The third argument chooses the field reference. `:column` reads
  # `field(r, ^field)`. `:expr` reads a dynamic expression in `field_expr`,
  # which is how custom fields configured with `:field_dynamic` are filtered.
  def op_config(op), do: op_config(op, true, :column)

  def op_config(op, ilike?) when is_boolean(ilike?) do
    op_config(op, ilike?, :column)
  end

  def op_config(:=~, false, source), do: op_config(:like, true, source)
  def op_config(:ilike, false, source), do: op_config(:like, true, source)

  def op_config(:not_ilike, false, source) do
    op_config(:not_like, true, source)
  end

  def op_config(:ilike_and, false, source) do
    op_config(:like_and, true, source)
  end

  def op_config(:ilike_or, false, source) do
    op_config(:like_or, true, source)
  end

  def op_config(:starts_with, false, source) do
    fragment = like_fragment(quote(do: ^var!(value)), source)
    {fragment, prelude(:add_wildcard_suffix), nil}
  end

  def op_config(:ends_with, false, source) do
    fragment = like_fragment(quote(do: ^var!(value)), source)
    {fragment, prelude(:add_wildcard_prefix), nil}
  end

  def op_config(:==, _ilike?, source) do
    fragment =
      quote do
        unquote(source_expr(source)) == ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:!=, _ilike?, source) do
    fragment =
      quote do
        unquote(source_expr(source)) != ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:>=, _ilike?, source) do
    fragment =
      quote do
        unquote(source_expr(source)) >= ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:<=, _ilike?, source) do
    fragment =
      quote do
        unquote(source_expr(source)) <= ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:>, _ilike?, source) do
    fragment =
      quote do
        unquote(source_expr(source)) > ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:<, _ilike?, source) do
    fragment =
      quote do
        unquote(source_expr(source)) < ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:in, _ilike?, source) do
    fragment =
      quote do
        unquote(source_expr(source)) in ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:contains, _ilike?, source) do
    fragment =
      quote do
        ^var!(value) in unquote(source_expr(source))
      end

    {fragment, nil, nil}
  end

  def op_config(:not_contains, _ilike?, source) do
    fragment =
      quote do
        ^var!(value) not in unquote(source_expr(source))
      end

    {fragment, nil, nil}
  end

  def op_config(:like, _ilike?, source) do
    fragment = like_fragment(quote(do: ^var!(value)), source)
    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:not_like, _ilike?, source) do
    fragment =
      quote do
        not unquote(like_fragment(quote(do: ^var!(value)), source))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:=~, _ilike?, source) do
    fragment =
      quote do
        ilike(unquote(source_expr(source)), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:ilike, _ilike?, source) do
    fragment =
      quote do
        ilike(unquote(source_expr(source)), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:not_ilike, _ilike?, source) do
    fragment =
      quote do
        not ilike(unquote(source_expr(source)), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:not_in, _ilike?, source) do
    fragment =
      quote do
        unquote(source_expr(source)) not in ^var!(processed_value) and
          not (^var!(reject_nil?) and is_nil(unquote(source_expr(source))))
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

  def op_config(:like_and, _ilike?, source) do
    fragment = like_fragment(quote(do: ^substring), source)
    combinator = :and
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:like_or, _ilike?, source) do
    fragment = like_fragment(quote(do: ^substring), source)
    combinator = :or
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:ilike_and, _ilike?, source) do
    fragment =
      quote do
        ilike(unquote(source_expr(source)), ^substring)
      end

    combinator = :and
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:ilike_or, _ilike?, source) do
    fragment =
      quote do
        ilike(unquote(source_expr(source)), ^substring)
      end

    combinator = :or
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:starts_with, _ilike?, source) do
    fragment =
      quote do
        ilike(unquote(source_expr(source)), ^var!(value))
      end

    prelude = prelude(:add_wildcard_suffix)
    {fragment, prelude, nil}
  end

  def op_config(:ends_with, _ilike?, source) do
    fragment =
      quote do
        ilike(unquote(source_expr(source)), ^var!(value))
      end

    prelude = prelude(:add_wildcard_prefix)
    {fragment, prelude, nil}
  end

  # `:column` is a schema or join field. `:expr` is a dynamic expression
  # produced by a custom field's `:field_dynamic` function.
  defp source_expr(:column) do
    quote do
      field(r, ^var!(field))
    end
  end

  defp source_expr(:expr) do
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
        unquote(source_expr(source)),
        unquote(pattern),
        ^"\\"
      )
    end
  end

  defmacro empty(kind, source \\ :column)

  defmacro empty(:array, source) do
    field = source_expr(source)

    quote do
      is_nil(unquote(field)) or
        unquote(field) == type(^[], ^var!(ecto_type))
    end
  end

  # for adapters that store an array as a JSON column
  defmacro empty(:json_array, source) do
    field = source_expr(source)

    quote do
      is_nil(unquote(field)) or
        fragment("JSON_LENGTH(?) = 0", unquote(field))
    end
  end

  defmacro empty(:map, source) do
    field = source_expr(source)

    quote do
      is_nil(unquote(field)) or
        unquote(field) == type(^%{}, ^var!(ecto_type))
    end
  end

  defmacro empty(:other, source) do
    field = source_expr(source)

    quote do
      is_nil(unquote(field))
    end
  end

  defmacro json_contains(source \\ :column) do
    field = source_expr(source)

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
