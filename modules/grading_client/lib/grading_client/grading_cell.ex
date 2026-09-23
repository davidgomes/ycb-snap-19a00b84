defmodule GradingClient.GradedCell do
  use Kino.JS
  use Kino.JS.Live
  use Kino.SmartCell, name: "Graded Cell"

  @impl true
  def init(attrs, ctx) do
    ctx =
      assign(ctx,
        module_id: attrs["module_id"],
        question_id: attrs["question_id"]
      )

    {:ok, ctx, editor: [attribute: "source", language: "elixir"]}
  end

  @impl true
  def handle_connect(ctx) do
    {:ok, %{module_id: ctx.assigns.module_id, question_id: ctx.assigns.question_id}, ctx}
  end

  @impl true
  def to_attrs(ctx) do
    %{"module_id" => ctx.assigns.module_id, "question_id" => ctx.assigns.question_id}
  end

  @impl true
  def to_source(attrs) do
    try do
      source = Code.string_to_quoted!(attrs["source"] || "")
      module_id = Module.concat([attrs["module_id"]])
      question_id = attrs["question_id"]

      ast =
        quote do
          result = unquote(source)

          case GradingClient.check_answer(result, unquote(module_id), unquote(question_id)) do
            :correct ->
              IO.puts([IO.ANSI.green(), "Correct!", IO.ANSI.reset()])

            {:incorrect, help_text} when is_binary(help_text) ->
              IO.puts([IO.ANSI.red(), "Incorrect: ", IO.ANSI.reset(), help_text])

            _ ->
              IO.puts([IO.ANSI.red(), "Incorrect.", IO.ANSI.reset()])
          end
        end

      Kino.SmartCell.quoted_to_string(ast)
    rescue
      error ->
        IO.inspect(error)
        attrs["source"]
    end
  end

  asset "main.js" do
    """
    export function init(ctx, payload) {
      ctx.importCSS("main.css");

      ctx.root.innerHTML = `
        <div class="app">
          Graded Cell (${payload.module_id} - Question ${payload.question_id})
        </div>
      `;
    }
    """
  end

  asset "main.css" do
    """
    .app {
      padding: 8px 16px;
      border: solid 1px #cad5e0;
      border-radius: 0.5rem 0.5rem 0 0;
      border-bottom: none;
    }
    """
  end
end
