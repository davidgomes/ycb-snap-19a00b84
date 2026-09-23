defmodule GradingClient.GradedCell do
  use Kino.JS
  use Kino.JS.Live
  use Kino.SmartCell, name: "Graded Cell"

  @impl true
  def init(attrs, ctx) do
    ctx =
      assign(ctx,
        module_id: attrs["module_id"] || "",
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
      source = Code.string_to_quoted!(attrs["source"])
      module_id = Module.concat([attrs["module_id"]])
      question_id = attrs["question_id"]

      ast =
        quote do
          answer = unquote(source)

          GradingClient.self_evaluate(answer, unquote(module_id), unquote(question_id))
        end

      Kino.SmartCell.quoted_to_string(ast)
    rescue
      # Fall back to the raw source so evaluation surfaces the syntax error to the user
      _error -> attrs["source"]
    end
  end

  asset "main.js" do
    """
    export function init(ctx, payload) {
      ctx.importCSS("main.css");

      const label = payload.question_id == null
        ? "Graded Cell"
        : `Graded Cell: ${payload.module_id} - Question ${payload.question_id}`;

      ctx.root.innerHTML = `<div class="app"></div>`;
      ctx.root.querySelector(".app").textContent = label;
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
