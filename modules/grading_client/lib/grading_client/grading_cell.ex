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
    {:ok, %{}, ctx}
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
  def to_source(%{"source" => source, "module_id" => module_id, "question_id" => question_id})
      when is_integer(module_id) and is_integer(question_id) do
    # The learner's source is only spliced in once it parses on its own, so it
    # cannot close the surrounding parentheses. Formatting the combined text
    # (rather than building an AST) keeps the learner's comments in place.
    case Code.string_to_quoted(source) do
      {:ok, _quoted} ->
        """
        result = (
        #{source}
        )

        GradingClient.check_answer(result, #{module_id}, #{question_id})
        """
        |> Code.format_string!()
        |> IO.iodata_to_binary()

      {:error, _reason} ->
        source
    end
  end

  def to_source(attrs), do: attrs["source"] || ""

  asset "main.js" do
    """
    export function init(ctx, payload) {
      ctx.importCSS("main.css");

      ctx.root.innerHTML = `
        <div class="app">
          Graded Cell
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
