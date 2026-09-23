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
  # `source` is `:field` for a schema or join field, or `:dynamic` when the
  # value being compared is an interpolated dynamic expression (`var!(expr)`).
  def op_config(op, source \\ :field)

  def op_config(:=~, false), do: op_config(:like)
  def op_config(:=~, false, source), do: op_config(:like, source)
  def op_config(:ilike, false), do: op_config(:like)
  def op_config(:ilike, false, source), do: op_config(:like, source)
  def op_config(:not_ilike, false), do: op_config(:not_like)
  def op_config(:not_ilike, false, source), do: op_config(:not_like, source)
  def op_config(:ilike_and, false), do: op_config(:like_and)
  def op_config(:ilike_and, false, source), do: op_config(:like_and, source)
  def op_config(:ilike_or, false), do: op_config(:like_or)
  def op_config(:ilike_or, false, source), do: op_config(:like_or, source)

  def op_config(:starts_with, false) do
    op_config(:starts_with, false, :field)
  end

  def op_config(:starts_with, false, source) do
    fragment = like_fragment(quote(do: ^var!(value)), source)
    {fragment, prelude(:add_wildcard_suffix), nil}
  end

  def op_config(:ends_with, false) do
    op_config(:ends_with, false, :field)
  end

  def op_config(:ends_with, false, source) do
    fragment = like_fragment(quote(do: ^var!(value)), source)
    {fragment, prelude(:add_wildcard_prefix), nil}
  end

  def op_config(op, ilike?) when is_boolean(ilike?), do: op_config(op)
  def op_config(op, true, source), do: op_config(op, source)

  def op_config(:==, source) do
    ref = field_ref(source)

    fragment =
      quote do
        unquote(ref) == ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:!=, source) do
    ref = field_ref(source)

    fragment =
      quote do
        unquote(ref) != ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:>=, source) do
    ref = field_ref(source)

    fragment =
      quote do
        unquote(ref) >= ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:<=, source) do
    ref = field_ref(source)

    fragment =
      quote do
        unquote(ref) <= ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:>, source) do
    ref = field_ref(source)

    fragment =
      quote do
        unquote(ref) > ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:<, source) do
    ref = field_ref(source)

    fragment =
      quote do
        unquote(ref) < ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:in, source) do
    ref = field_ref(source)

    fragment =
      quote do
        unquote(ref) in ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:contains, source) do
    ref = field_ref(source)

    fragment =
      quote do
        ^var!(value) in unquote(ref)
      end

    {fragment, nil, nil}
  end

  def op_config(:not_contains, source) do
    ref = field_ref(source)

    fragment =
      quote do
        ^var!(value) not in unquote(ref)
      end

    {fragment, nil, nil}
  end

  def op_config(:like, source) do
    fragment = like_fragment(quote(do: ^var!(value)), source)
    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:not_like, source) do
    fragment =
      quote do
        not unquote(like_fragment(quote(do: ^var!(value)), source))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:=~, source) do
    ref = field_ref(source)

    fragment =
      quote do
        ilike(unquote(ref), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:ilike, source) do
    ref = field_ref(source)

    fragment =
      quote do
        ilike(unquote(ref), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:not_ilike, source) do
    ref = field_ref(source)

    fragment =
      quote do
        not ilike(unquote(ref), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:not_in, source) do
    ref = field_ref(source)

    fragment =
      quote do
        unquote(ref) not in ^var!(processed_value) and
          not (^var!(reject_nil?) and is_nil(unquote(ref)))
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
    fragment = like_fragment(quote(do: ^substring), source)
    combinator = :and
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:like_or, source) do
    fragment = like_fragment(quote(do: ^substring), source)
    combinator = :or
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:ilike_and, source) do
    ref = field_ref(source)

    fragment =
      quote do
        ilike(unquote(ref), ^substring)
      end

    combinator = :and
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:ilike_or, source) do
    ref = field_ref(source)

    fragment =
      quote do
        ilike(unquote(ref), ^substring)
      end

    combinator = :or
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:starts_with, source) do
    ref = field_ref(source)

    fragment =
      quote do
        ilike(unquote(ref), ^var!(value))
      end

    prelude = prelude(:add_wildcard_suffix)
    {fragment, prelude, nil}
  end

  def op_config(:ends_with, source) do
    ref = field_ref(source)

    fragment =
      quote do
        ilike(unquote(ref), ^var!(value))
      end

    prelude = prelude(:add_wildcard_prefix)
    {fragment, prelude, nil}
  end

  defp field_ref(:field) do
    quote do: field(r, ^var!(field))
  end

  defp field_ref(:dynamic) do
    quote do: ^var!(expr)
  end

  # The escape character must be bound rather than written into the fragment
  # because no literal works everywhere. MySQL reads '\' as an incomplete string
  # escape, SQLite and Postgres read '\\' as two characters.
  defp like_fragment(pattern, source) do
    ref = field_ref(source)

    quote do
      fragment(
        "? LIKE ? ESCAPE ?",
        unquote(ref),
        unquote(pattern),
        ^"\\"
      )
    end
  end

  defmacro empty(kind, source \\ :field)

  defmacro empty(:array, source) do
    ref = field_ref(source)

    quote do
      is_nil(unquote(ref)) or
        unquote(ref) == type(^[], ^var!(ecto_type))
    end
  end

  # for adapters that store an array as a JSON column
  defmacro empty(:json_array, source) do
    ref = field_ref(source)

    quote do
      is_nil(unquote(ref)) or
        fragment("JSON_LENGTH(?) = 0", unquote(ref))
    end
  end

  defmacro empty(:map, source) do
    ref = field_ref(source)

    quote do
      is_nil(unquote(ref)) or
        unquote(ref) == type(^%{}, ^var!(ecto_type))
    end
  end

  defmacro empty(:other, source) do
    ref = field_ref(source)

    quote do
      is_nil(unquote(ref))
    end
  end

  defmacro json_contains(source \\ :field) do
    ref = field_ref(source)

    quote do
      fragment(
        "JSON_CONTAINS(?, ?)",
        unquote(ref),
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
