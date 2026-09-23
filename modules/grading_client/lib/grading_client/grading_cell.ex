defmodule GradingClient.GradedCell do
  use Kino.JS
  use Kino.JS.Live
  use Kino.SmartCell, name: "Graded Cell"

  @impl true
  def init(attrs, ctx) do
    source = attrs["source"] || ""

    ctx =
      assign(ctx,
        source: source,
        module_id: attrs["module_id"],
        question_id: attrs["question_id"]
      )

    {:ok, ctx, editor: [source: source, language: "elixir"]}
  end

  @impl true
  def handle_connect(ctx) do
    {:ok, %{module_id: ctx.assigns.module_id, question_id: ctx.assigns.question_id}, ctx}
  end

  @impl true
  def handle_editor_change(source, ctx) do
    {:ok, assign(ctx, source: source)}
  end

  @impl true
  def to_attrs(ctx) do
    %{
      "source" => ctx.assigns.source,
      "module_id" => ctx.assigns.module_id,
      "question_id" => ctx.assigns.question_id
    }
  end

  @impl true
  def to_source(attrs) do
    case Code.string_to_quoted(attrs["source"]) do
      {:ok, answer} ->
        quote do
          result = unquote(answer)
          GradingClient.grade(result, unquote(attrs["module_id"]), unquote(attrs["question_id"]))
        end
        |> Kino.SmartCell.quoted_to_string()

      # Keep invalid code as-is, so evaluating the cell reports the syntax error
      {:error, _} ->
        attrs["source"]
    end
  end

  asset "main.js" do
    """
    export function init(ctx, payload) {
      ctx.importCSS("main.css");

      ctx.root.innerHTML = `
        <div class="app">
          <span class="title">Graded Cell</span>
          <span class="question"></span>
        </div>
      `;

      if (payload.module_id !== null && payload.question_id !== null) {
        ctx.root.querySelector(".question").textContent =
          `${payload.module_id} - Question ${payload.question_id}`;
      }
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

    .question {
      margin-left: 8px;
      color: #61758a;
    }
    """
  end
end
