defmodule Ocelot.HTML.Engine do
  @moduledoc false

  # An EEx engine that HTML-escapes every `<%= %>` expression unless it is
  # already a `{:safe, iodata}` tuple. Rendered templates and nested blocks are
  # returned as `{:safe, binary}` so they are never escaped twice.

  @behaviour EEx.Engine

  @impl true
  defdelegate init(opts), to: EEx.Engine

  @impl true
  defdelegate handle_text(state, meta, text), to: EEx.Engine

  @impl true
  defdelegate handle_begin(state), to: EEx.Engine

  @impl true
  def handle_end(quoted), do: safe(EEx.Engine.handle_end(quoted))

  @impl true
  def handle_body(state), do: safe(EEx.Engine.handle_body(state))

  @impl true
  def handle_expr(state, "=", ast) do
    ast = quote do: Ocelot.HTML.escape(unquote(expand_assigns(ast)))
    EEx.Engine.handle_expr(state, "=", ast)
  end

  def handle_expr(state, marker, ast) do
    EEx.Engine.handle_expr(state, marker, expand_assigns(ast))
  end

  defp expand_assigns(ast), do: Macro.prewalk(ast, &EEx.Engine.handle_assign/1)

  defp safe(body), do: quote(do: {:safe, unquote(body)})
end
