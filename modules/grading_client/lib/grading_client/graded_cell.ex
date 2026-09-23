defmodule GradingClient.GradedCell do
  use Kino.JS
  use Kino.JS.Live
  use Kino.SmartCell, name: "Graded Cell"

  @impl true
  def init(attrs, ctx) do
    source = attrs["source"] || ""

    {:ok, assign(ctx, source: source), editor: [source: source, language: "elixir"]}
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
    modules = Map.new(GradingClient.Answers.get_modules(), &{inspect(&1), &1})

    source_ast =
      try do
        source_attr = attrs["source"]
        source = Code.string_to_quoted!(source_attr)

        case parse_question_header(source_attr, modules) do
          {:ok, module_id, question_id} ->
            quote do
              result = unquote(source)

              case GradingClient.check_answer(unquote(module_id), unquote(question_id), result) do
                :correct ->
                  IO.puts([IO.ANSI.green(), "Correct!", IO.ANSI.reset()])

                {:incorrect, help_text} when is_binary(help_text) ->
                  IO.puts([IO.ANSI.red(), "Incorrect: ", IO.ANSI.reset(), help_text])

                _ ->
                  IO.puts([IO.ANSI.red(), "Incorrect.", IO.ANSI.reset()])
              end
            end

          {:error, message} ->
            quote do
              raise unquote(message)
            end
        end
      rescue
        error ->
          IO.inspect(error)
          {:<<>>, [delimiter: ~s["""]], [attrs["source"] <> "\n"]}
      end

    Kino.SmartCell.quoted_to_string(source_ast)
  end

  defp parse_question_header(source, modules) do
    header =
      source
      |> String.split("\n", parts: 2)
      |> hd()
      |> String.trim_leading("#")

    case String.split(header, ":", parts: 2) do
      [module_id, question_id] ->
        with {:ok, module_id} <- parse_module_id(String.trim(module_id), modules),
             {:ok, question_id} <- parse_question_id(String.trim(question_id)) do
          {:ok, module_id, question_id}
        end

      _ ->
        {:error, "invalid question header: #{String.trim(header)}"}
    end
  end

  defp parse_module_id(module_id, modules) do
    case modules[module_id] do
      nil -> {:error, "invalid module id: #{module_id}"}
      module -> {:ok, module}
    end
  end

  defp parse_question_id(question_id) do
    case Integer.parse(question_id) do
      {id, ""} -> {:ok, id}
      _ -> {:error, "invalid question id: #{question_id}"}
    end
  end

  @impl true
  def handle_connect(ctx) do
    {:ok, %{}, ctx}
  end

  asset "main.js" do
    """
    export function init(ctx, payload) {
      ctx.importCSS("main.css");

      root.innerHTML = `
        <div class="app">
          <div class="text-lg font-bold">Graded Cell</div>
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
