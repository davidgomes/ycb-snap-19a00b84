defmodule ObanDoctor.ObanConfigDiscovery do
  @moduledoc """
  Discovers Oban configuration from config files.

  Parses config/*.exs files to find queue definitions.
  """

  @doc """
  Discovers all defined queues from config files.

  Returns a MapSet of queue names (atoms).
  """
  def discover_queues(root_path) do
    config_files = [
      Path.join(root_path, "config/config.exs"),
      Path.join(root_path, "config/dev.exs"),
      Path.join(root_path, "config/prod.exs"),
      Path.join(root_path, "config/runtime.exs")
    ]

    config_files
    |> Enum.filter(&File.exists?/1)
    |> Enum.flat_map(&extract_queues_from_file/1)
    |> MapSet.new()
  end

  defp extract_queues_from_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        extract_queues_from_content(content)

      {:error, _} ->
        []
    end
  end

  defp extract_queues_from_content(content) do
    case Code.string_to_quoted(content, columns: true) do
      {:ok, ast} ->
        extract_queues_from_ast(ast)

      {:error, _} ->
        []
    end
  end

  defp extract_queues_from_ast(ast) do
    {_ast, queues} =
      Macro.prewalk(ast, [], fn
        # Match queues: [queue1: limit, queue2: limit, ...]
        {:queues, list} = node, acc when is_list(list) ->
          queue_names = extract_queue_names(list)
          {node, queue_names ++ acc}

        # Match {:queues, [queue1: limit, ...]}
        {{:queues, list}, _} = node, acc when is_list(list) ->
          queue_names = extract_queue_names(list)
          {node, queue_names ++ acc}

        node, acc ->
          {node, acc}
      end)

    queues
  end

  defp extract_queue_names(list) when is_list(list) do
    Enum.flat_map(list, fn
      {queue_name, _limit} when is_atom(queue_name) -> [queue_name]
      _ -> []
    end)
  end
end
