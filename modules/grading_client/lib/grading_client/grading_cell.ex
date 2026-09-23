defmodule GradingClient.GradedCell do
  use Kino.JS
  use Kino.JS.Live
  use Kino.SmartCell, name: "Graded Cell"

  @impl true
  def init(attrs, ctx) do
    source = attrs["source"] || ""
    module_id = attrs["module_id"] || ""
    question_id = attrs["question_id"] || 1

    {:ok, assign(ctx, source: source, module_id: module_id, question_id: question_id),
     editor: [source: source, language: "elixir"]}
  end

  @impl true
  def handle_connect(ctx) do
    {:ok, %{module_id: ctx.assigns.module_id, question_id: ctx.assigns.question_id}, ctx}
  end

  @impl true
  def handle_event("update_module_id", module_id, ctx) do
    {:noreply, assign(ctx, module_id: String.trim(module_id))}
  end

  def handle_event("update_question_id", question_id, ctx) do
    case Integer.parse(to_string(question_id)) do
      {question_id, ""} -> {:noreply, assign(ctx, question_id: question_id)}
      _ -> {:noreply, ctx}
    end
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
  def to_source(%{"module_id" => module_id} = attrs) when module_id in [nil, ""] do
    attrs["source"]
  end

  def to_source(attrs) do
    try do
      source = Code.string_to_quoted!(attrs["source"])
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
      _error -> attrs["source"]
    end
  end

  asset "main.js" do
    """
    export function init(ctx, payload) {
      ctx.importCSS("main.css");

      ctx.root.innerHTML = `
        <div class="app">
          <span class="title">Graded Cell</span>
          <label>
            Module
            <input type="text" name="module_id" />
          </label>
          <label>
            Question
            <input type="number" name="question_id" min="1" />
          </label>
        </div>
      `;

      const moduleInput = ctx.root.querySelector(`[name="module_id"]`);
      const questionInput = ctx.root.querySelector(`[name="question_id"]`);

      moduleInput.value = payload.module_id;
      questionInput.value = payload.question_id;

      moduleInput.addEventListener("change", (event) => {
        ctx.pushEvent("update_module_id", event.target.value);
      });

      questionInput.addEventListener("change", (event) => {
        ctx.pushEvent("update_question_id", event.target.value);
      });
    }
    """
  end

  asset "main.css" do
    """
    .app {
      display: flex;
      align-items: center;
      gap: 16px;
      padding: 8px 16px;
      border: solid 1px #cad5e0;
      border-radius: 0.5rem 0.5rem 0 0;
      border-bottom: none;
      font-family: sans-serif;
      font-size: 14px;
    }

    .title {
      font-weight: 600;
    }

    input {
      width: 80px;
      margin-left: 4px;
    }
    """
  end
end
