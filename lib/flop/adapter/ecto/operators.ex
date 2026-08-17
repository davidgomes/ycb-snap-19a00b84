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

  def schema_field_ast do
    quote do
      field(r, ^var!(field))
    end
  end

  def dynamic_field_ast do
    quote do
      ^var!(expr)
    end
  end

  # The second argument says whether the repo adapter supports ILIKE. If it
  # doesn't, ILIKE is replaced with LIKE. See Flop.Adapter.Ecto.Dialect.
  def op_config(op), do: op_config_field(op, schema_field_ast())

  def op_config(op, ilike?) when is_boolean(ilike?) do
    op_config(op, ilike?, schema_field_ast())
  end

  def op_config(op, field), do: op_config_field(op, field)

  def op_config(:=~, false, field), do: op_config_field(:like, field)
  def op_config(:ilike, false, field), do: op_config_field(:like, field)
  def op_config(:not_ilike, false, field), do: op_config_field(:not_like, field)
  def op_config(:ilike_and, false, field), do: op_config_field(:like_and, field)
  def op_config(:ilike_or, false, field), do: op_config_field(:like_or, field)

  def op_config(:starts_with, false, field) do
    fragment = like_fragment(field, quote(do: ^var!(value)))
    {fragment, prelude(:add_wildcard_suffix), nil}
  end

  def op_config(:ends_with, false, field) do
    fragment = like_fragment(field, quote(do: ^var!(value)))
    {fragment, prelude(:add_wildcard_prefix), nil}
  end

  def op_config(op, _ilike?, field), do: op_config_field(op, field)

  def op_config_field(:==, field) do
    fragment =
      quote do
        unquote(field) == ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config_field(:!=, field) do
    fragment =
      quote do
        unquote(field) != ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config_field(:>=, field) do
    fragment =
      quote do
        unquote(field) >= ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config_field(:<=, field) do
    fragment =
      quote do
        unquote(field) <= ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config_field(:>, field) do
    fragment =
      quote do
        unquote(field) > ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config_field(:<, field) do
    fragment =
      quote do
        unquote(field) < ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config_field(:in, field) do
    fragment =
      quote do
        unquote(field) in ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config_field(:contains, field) do
    fragment =
      quote do
        ^var!(value) in unquote(field)
      end

    {fragment, nil, nil}
  end

  def op_config_field(:not_contains, field) do
    fragment =
      quote do
        ^var!(value) not in unquote(field)
      end

    {fragment, nil, nil}
  end

  def op_config_field(:like, field) do
    fragment = like_fragment(field, quote(do: ^var!(value)))
    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config_field(:not_like, field) do
    fragment =
      quote do
        not unquote(like_fragment(field, quote(do: ^var!(value))))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config_field(:=~, field) do
    fragment =
      quote do
        ilike(unquote(field), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config_field(:ilike, field) do
    fragment =
      quote do
        ilike(unquote(field), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config_field(:not_ilike, field) do
    fragment =
      quote do
        not ilike(unquote(field), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config_field(:not_in, field) do
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

  def op_config_field(:like_and, field) do
    fragment = like_fragment(field, quote(do: ^substring))
    combinator = :and
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config_field(:like_or, field) do
    fragment = like_fragment(field, quote(do: ^substring))
    combinator = :or
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config_field(:ilike_and, field) do
    fragment =
      quote do
        ilike(unquote(field), ^substring)
      end

    combinator = :and
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config_field(:ilike_or, field) do
    fragment =
      quote do
        ilike(unquote(field), ^substring)
      end

    combinator = :or
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config_field(:starts_with, field) do
    fragment =
      quote do
        ilike(unquote(field), ^var!(value))
      end

    prelude = prelude(:add_wildcard_suffix)
    {fragment, prelude, nil}
  end

  def op_config_field(:ends_with, field) do
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
  defp like_fragment(field, pattern) do
    quote do
      fragment(
        "? LIKE ? ESCAPE ?",
        unquote(field),
        unquote(pattern),
        ^"\\"
      )
    end
  end

  defmacro empty(kind), do: empty_ast(kind, schema_field_ast())
  defmacro empty(kind, field), do: empty_ast(kind, field)

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

  defmacro json_contains, do: json_contains_ast(schema_field_ast())
  defmacro json_contains(field), do: json_contains_ast(field)

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
