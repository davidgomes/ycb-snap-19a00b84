defmodule Ocelot.HTML.Engine do
  @moduledoc false

  # An EEx engine that HTML-escapes every `<%= %>` expression. Nested blocks
  # (`for`, `if`, ...) are marked as safe so their markup isn't escaped twice.
  # Use `Ocelot.HTML.raw/1` to output trusted markup as-is.

  @behaviour EEx.Engine

  @impl true
  defdelegate init(opts), to: EEx.Engine

  @impl true
  defdelegate handle_body(state), to: EEx.Engine

  @impl true
  defdelegate handle_begin(state), to: EEx.Engine

  @impl true
  defdelegate handle_text(state, meta, text), to: EEx.Engine

  @impl true
  def handle_end(quoted) do
    quote do: {:safe, unquote(EEx.Engine.handle_end(quoted))}
  end

  @impl true
  def handle_expr(state, "=", ast) do
    EEx.SmartEngine.handle_expr(state, "=", quote(do: Ocelot.HTML.escape(unquote(ast))))
  end

  def handle_expr(state, marker, ast), do: EEx.SmartEngine.handle_expr(state, marker, ast)
end
