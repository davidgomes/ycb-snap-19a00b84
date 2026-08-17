defmodule ObanDoctor.WorkerDiscovery do
  @moduledoc """
  Discovers Oban workers by parsing source files.
  """

  @doc """
  Discovers all Oban workers in the given directory.

  Returns a list of worker info maps containing:
  - `:module` - The worker module name (atom)
  - `:file` - Path to the source file
  - `:line` - Line number where the module is defined
  - `:queue` - The queue option if specified
  - `:unique` - The unique option if specified
  - `:max_attempts` - The max_attempts option if specified
  - `:uses_oban_worker` - Whether it uses `Oban.Worker` or `Oban.Pro.Worker`
  """
  def discover(root_path) do
    patterns = [
      Path.join(root_path, "lib/**/*.ex"),
      Path.join(root_path, "apps/*/lib/**/*.ex")
    ]

    patterns
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.flat_map(&parse_file/1)
    |> Enum.filter(&oban_worker?/1)
  end

  defp parse_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        parse_content(content, file_path)

      {:error, _} ->
        []
    end
  end

  defp parse_content(content, file_path) do
    case Code.string_to_quoted(content, columns: true, token_metadata: true) do
      {:ok, ast} ->
        extract_modules(ast, file_path)

      {:error, _} ->
        []
    end
  end

  defp extract_modules(ast, file_path) do
    {_ast, modules} =
      Macro.prewalk(ast, [], fn
        {:defmodule, meta, [module_alias, [do: body]]} = node, acc ->
          module_info = %{
            module: extract_module_name(module_alias),
            file: file_path,
            line: Keyword.get(meta, :line, 1),
            uses_oban_worker: false,
            queue: nil,
            unique: nil,
            max_attempts: nil
          }

          module_info = analyze_module_body(body, module_info)
          {node, [module_info | acc]}

        node, acc ->
          {node, acc}
      end)

    modules
  end

  defp extract_module_name({:__aliases__, _, parts}) do
    Module.concat(parts)
  end

  defp extract_module_name(other), do: other

  defp analyze_module_body({:__block__, _, statements}, info) do
    Enum.reduce(statements, info, &analyze_statement/2)
  end

  defp analyze_module_body(statement, info) do
    analyze_statement(statement, info)
  end

  defp analyze_statement({:use, _, args}, info) do
    case extract_use_module(args) do
      {:oban_worker, opts} ->
        info
        |> Map.put(:uses_oban_worker, true)
        |> extract_worker_opts(opts)

      {:oban_pro_worker, opts} ->
        info
        |> Map.put(:uses_oban_worker, true)
        |> Map.put(:is_pro, true)
        |> extract_worker_opts(opts)

      _ ->
        info
    end
  end

  defp analyze_statement(_, info), do: info

  defp extract_use_module([{:__aliases__, _, [:Oban, :Worker]} | rest]) do
    {:oban_worker, extract_opts(rest)}
  end

  defp extract_use_module([{:__aliases__, _, [:Oban, :Pro, :Worker]} | rest]) do
    {:oban_pro_worker, extract_opts(rest)}
  end

  defp extract_use_module(_), do: nil

  defp extract_opts([]), do: []
  defp extract_opts([opts]) when is_list(opts), do: opts
  defp extract_opts(_), do: []

  defp extract_worker_opts(info, opts) do
    info
    |> maybe_put_opt(:queue, opts)
    |> maybe_put_opt(:unique, opts)
    |> maybe_put_opt(:max_attempts, opts)
  end

  defp maybe_put_opt(info, key, opts) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> Map.put(info, key, extract_value(value))
      :error -> info
    end
  end

  defp extract_value({:__block__, _, [value]}), do: extract_value(value)
  defp extract_value(value) when is_atom(value), do: value
  defp extract_value(value) when is_integer(value), do: value
  defp extract_value(value) when is_list(value), do: Enum.map(value, &extract_keyword_pair/1)
  defp extract_value({:{}, _, elements}), do: List.to_tuple(Enum.map(elements, &extract_value/1))
  defp extract_value(other), do: other

  defp extract_keyword_pair({key, value}) when is_atom(key) do
    {key, extract_value(value)}
  end

  defp extract_keyword_pair(other), do: other

  defp oban_worker?(%{uses_oban_worker: true}), do: true
  defp oban_worker?(_), do: false
end
