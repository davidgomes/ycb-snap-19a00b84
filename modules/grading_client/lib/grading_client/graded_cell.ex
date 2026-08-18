defmodule GradingClient.GradedCell do
  @moduledoc """
  Smart cell that evaluates the answer written by the reader and
  immediately reports back whether it is correct.

  The cell renders inputs for picking the module and the question being
  answered, evaluates the code from the cell editor and grades the value it
  returns against `GradingClient.Answers`.
  """

  use Kino.JS
  use Kino.JS.Live
  use Kino.SmartCell, name: "Graded Cell"

  @impl true
  def init(attrs, ctx) do
    source = attrs["source"] || ""

    {:ok, assign(ctx, source: source), editor: [source: source, language: "elixir"]}
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
    %{"source" => ctx.assigns.source}
  end

  @impl true
  def to_source(attrs) do
    [
      Kino.SmartCell.quoted_to_string(inputs_quoted()),
      Kino.SmartCell.quoted_to_string(evaluation_quoted(attrs))
    ]
  end

  defp inputs_quoted do
    options = Enum.map(GradingClient.Answers.get_modules(), &{&1, inspect(&1)})

    quote do
      module_id = Kino.Input.select("Module", unquote(options))
      question_id = Kino.Input.number("Question ID")

      Kino.render(Kino.Layout.grid([module_id, question_id], columns: 2))
      nil
    end
  end

  defp evaluation_quoted(attrs) do
    source = Code.string_to_quoted!(attrs["source"])

    quote do
      module_id = Kino.Input.read(module_id)
      question_id = Kino.Input.read(question_id)

      result = unquote(source)

      case GradingClient.check_answer(module_id, question_id, result) do
        :correct ->
          IO.puts([IO.ANSI.green(), "Correct!", IO.ANSI.reset()])

        {:incorrect, help_text} when is_binary(help_text) ->
          IO.puts([IO.ANSI.red(), "Incorrect: ", IO.ANSI.reset(), help_text])

        _ ->
          IO.puts([IO.ANSI.red(), "Incorrect.", IO.ANSI.reset()])
      end
    end
  rescue
    error ->
      # The editor contents are not valid Elixir yet, so keep them around as a
      # string literal instead of dropping what has been written so far.
      IO.inspect(error)
      {:<<>>, [delimiter: ~s["""]], [attrs["source"] <> "\n"]}
  end

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
