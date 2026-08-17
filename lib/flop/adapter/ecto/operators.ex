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
  def op_config(:=~, false), do: op_config(:like)
  def op_config(:ilike, false), do: op_config(:like)
  def op_config(:not_ilike, false), do: op_config(:not_like)
  def op_config(:ilike_and, false), do: op_config(:like_and)
  def op_config(:ilike_or, false), do: op_config(:like_or)

  def op_config(:starts_with, false) do
    fragment = like_fragment(quote(do: ^var!(value)))
    {fragment, prelude(:add_wildcard_suffix), nil}
  end

  def op_config(:ends_with, false) do
    fragment = like_fragment(quote(do: ^var!(value)))
    {fragment, prelude(:add_wildcard_prefix), nil}
  end

  def op_config(op, _ilike?), do: op_config(op)

  def op_config(:==) do
    fragment =
      quote do
        field(r, ^var!(field)) == ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:!=) do
    fragment =
      quote do
        field(r, ^var!(field)) != ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:>=) do
    fragment =
      quote do
        field(r, ^var!(field)) >= ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:<=) do
    fragment =
      quote do
        field(r, ^var!(field)) <= ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:>) do
    fragment =
      quote do
        field(r, ^var!(field)) > ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:<) do
    fragment =
      quote do
        field(r, ^var!(field)) < ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:in) do
    fragment =
      quote do
        field(r, ^var!(field)) in ^var!(value)
      end

    {fragment, nil, nil}
  end

  def op_config(:contains) do
    fragment =
      quote do
        ^var!(value) in field(r, ^var!(field))
      end

    {fragment, nil, nil}
  end

  def op_config(:not_contains) do
    fragment =
      quote do
        ^var!(value) not in field(r, ^var!(field))
      end

    {fragment, nil, nil}
  end

  def op_config(:like) do
    fragment = like_fragment(quote(do: ^var!(value)))
    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:not_like) do
    fragment =
      quote do
        not unquote(like_fragment(quote(do: ^var!(value))))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:=~) do
    fragment =
      quote do
        ilike(field(r, ^var!(field)), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:ilike) do
    fragment =
      quote do
        ilike(field(r, ^var!(field)), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:not_ilike) do
    fragment =
      quote do
        not ilike(field(r, ^var!(field)), ^var!(value))
      end

    prelude = prelude(:add_wildcard)
    {fragment, prelude, nil}
  end

  def op_config(:not_in) do
    fragment =
      quote do
        field(r, ^var!(field)) not in ^var!(processed_value) and
          not (^var!(reject_nil?) and is_nil(field(r, ^var!(field))))
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

  def op_config(:like_and) do
    fragment = like_fragment(quote(do: ^substring))
    combinator = :and
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:like_or) do
    fragment = like_fragment(quote(do: ^substring))
    combinator = :or
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:ilike_and) do
    fragment =
      quote do
        ilike(field(r, ^var!(field)), ^substring)
      end

    combinator = :and
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:ilike_or) do
    fragment =
      quote do
        ilike(field(r, ^var!(field)), ^substring)
      end

    combinator = :or
    prelude = prelude(:maybe_split_search_text)

    {fragment, prelude, combinator}
  end

  def op_config(:starts_with) do
    fragment =
      quote do
        ilike(field(r, ^var!(field)), ^var!(value))
      end

    prelude = prelude(:add_wildcard_suffix)
    {fragment, prelude, nil}
  end

  def op_config(:ends_with) do
    fragment =
      quote do
        ilike(field(r, ^var!(field)), ^var!(value))
      end

    prelude = prelude(:add_wildcard_prefix)
    {fragment, prelude, nil}
  end

  # `field_dynamic` variants of the `op_config/1` and `op_config/2` clauses
  # above, used to filter custom fields via a `field_dynamic` function
  # instead of a schema field. The prelude and combinator are always the same
  # as for the schema field variant, so they are not repeated here.

  def op_config_dynamic(:=~, false), do: op_config_dynamic(:like)
  def op_config_dynamic(:ilike, false), do: op_config_dynamic(:like)
  def op_config_dynamic(:not_ilike, false), do: op_config_dynamic(:not_like)
  def op_config_dynamic(:ilike_and, false), do: op_config_dynamic(:like_and)
  def op_config_dynamic(:ilike_or, false), do: op_config_dynamic(:like_or)

  def op_config_dynamic(:starts_with, false) do
    like_fragment_dynamic(quote(do: ^var!(value)))
  end

  def op_config_dynamic(:ends_with, false) do
    like_fragment_dynamic(quote(do: ^var!(value)))
  end

  def op_config_dynamic(op, _ilike?), do: op_config_dynamic(op)

  def op_config_dynamic(:==) do
    quote do
      ^var!(field_dynamic) == ^var!(value)
    end
  end

  def op_config_dynamic(:!=) do
    quote do
      ^var!(field_dynamic) != ^var!(value)
    end
  end

  def op_config_dynamic(:>=) do
    quote do
      ^var!(field_dynamic) >= ^var!(value)
    end
  end

  def op_config_dynamic(:<=) do
    quote do
      ^var!(field_dynamic) <= ^var!(value)
    end
  end

  def op_config_dynamic(:>) do
    quote do
      ^var!(field_dynamic) > ^var!(value)
    end
  end

  def op_config_dynamic(:<) do
    quote do
      ^var!(field_dynamic) < ^var!(value)
    end
  end

  def op_config_dynamic(:in) do
    quote do
      ^var!(field_dynamic) in ^var!(value)
    end
  end

  def op_config_dynamic(:contains) do
    quote do
      ^var!(value) in ^var!(field_dynamic)
    end
  end

  def op_config_dynamic(:not_contains) do
    quote do
      ^var!(value) not in ^var!(field_dynamic)
    end
  end

  def op_config_dynamic(:like) do
    like_fragment_dynamic(quote(do: ^var!(value)))
  end

  def op_config_dynamic(:not_like) do
    quote do
      not unquote(like_fragment_dynamic(quote(do: ^var!(value))))
    end
  end

  def op_config_dynamic(:=~) do
    quote do
      ilike(^var!(field_dynamic), ^var!(value))
    end
  end

  def op_config_dynamic(:ilike) do
    quote do
      ilike(^var!(field_dynamic), ^var!(value))
    end
  end

  def op_config_dynamic(:not_ilike) do
    quote do
      not ilike(^var!(field_dynamic), ^var!(value))
    end
  end

  def op_config_dynamic(:not_in) do
    quote do
      ^var!(field_dynamic) not in ^var!(processed_value) and
        not (^var!(reject_nil?) and is_nil(^var!(field_dynamic)))
    end
  end

  def op_config_dynamic(:like_and) do
    like_fragment_dynamic(quote(do: ^substring))
  end

  def op_config_dynamic(:like_or) do
    like_fragment_dynamic(quote(do: ^substring))
  end

  def op_config_dynamic(:ilike_and) do
    quote do
      ilike(^var!(field_dynamic), ^substring)
    end
  end

  def op_config_dynamic(:ilike_or) do
    quote do
      ilike(^var!(field_dynamic), ^substring)
    end
  end

  def op_config_dynamic(:starts_with) do
    quote do
      ilike(^var!(field_dynamic), ^var!(value))
    end
  end

  def op_config_dynamic(:ends_with) do
    quote do
      ilike(^var!(field_dynamic), ^var!(value))
    end
  end

  # The escape character must be bound rather than written into the fragment
  # because no literal works everywhere. MySQL reads '\' as an incomplete string
  # escape, SQLite and Postgres read '\\' as two characters.
  defp like_fragment(pattern) do
    quote do
      fragment(
        "? LIKE ? ESCAPE ?",
        field(r, ^var!(field)),
        unquote(pattern),
        ^"\\"
      )
    end
  end

  # Same as `like_fragment/1`, but for custom fields that are filtered via a
  # `field_dynamic` function instead of a schema field.
  defp like_fragment_dynamic(pattern) do
    quote do
      fragment(
        "? LIKE ? ESCAPE ?",
        ^var!(field_dynamic),
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

  # `field_dynamic` variants of the `empty/1` and `json_contains/0` macros
  # above, used to filter custom fields via a `field_dynamic` function.
  #
  # There are no `:array` and `:map` variants of this macro. Combining a
  # pinned `field_dynamic` expression with `type(^[], ^ecto_type)` (where
  # `ecto_type` is itself a runtime variable rather than a literal) in the
  # same `dynamic/2` call confuses Ecto's pin escaping, so those two cases are
  # built directly in `Flop.Adapter.Ecto.build_op/5` instead, by computing the
  # correctly typed empty value in a separate `dynamic/2` call first.

  defmacro empty_dynamic(:json_array) do
    quote do
      is_nil(^var!(field_dynamic)) or
        fragment("JSON_LENGTH(?) = 0", ^var!(field_dynamic))
    end
  end

  defmacro empty_dynamic(:other) do
    quote do
      is_nil(^var!(field_dynamic))
    end
  end

  defmacro json_contains_dynamic do
    quote do
      fragment(
        "JSON_CONTAINS(?, ?)",
        ^var!(field_dynamic),
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
