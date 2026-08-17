defmodule ObanDoctor.ObanDiscovery do
  @moduledoc """
  Discovers Oban configuration from config files.

  Parses config/*.exs files to find Oban instances and their configurations,
  including queues, plugins, and settings.
  """

  @config_files [
    "config/config.exs",
    "config/dev.exs",
    "config/prod.exs",
    "config/runtime.exs"
  ]

  @doc """
  Discovers all Oban instance configurations from config files.

  Configs for the same instance (same app + name) are merged in order:
  config.exs < dev.exs/prod.exs < runtime.exs

  Returns a list of Oban config maps:

      [
        %{
          name: Oban,                     # Instance name (Oban if not specified)
          app: :myapp,                    # App key from config
          repo: MyApp.Repo,               # Repo module (nil if not found)
          queues: [:default, :emails],    # Queue names (merged from all configs)
          plugins: [Oban.Plugins.Pruner], # Plugin modules (merged from all configs)
          insert_trigger: false,          # insert_trigger setting (nil if never set)
          engine: Oban.Pro.Engines.Smart, # Engine module (nil if not set)
          file: "config/config.exs",      # Primary source file (first definition)
          line: 95                        # Line number of first definition
        }
      ]
  """
  def discover_oban_configs(root_path) do
    @config_files
    |> Enum.map(&Path.join(root_path, &1))
    |> Enum.filter(&File.exists?/1)
    |> Enum.flat_map(&extract_oban_configs_from_file/1)
    |> merge_configs_by_instance()
  end

  # Merge configs for the same (app, name) combination.
  # Later configs override earlier ones, mimicking Elixir's Config behavior.
  defp merge_configs_by_instance(configs) do
    configs
    |> Enum.reduce(%{}, fn config, acc ->
      key = {config.app, config.name}

      case Map.get(acc, key) do
        nil ->
          Map.put(acc, key, config)

        existing ->
          merged = merge_two_configs(existing, config)
          Map.put(acc, key, merged)
      end
    end)
    |> Map.values()
  end

  # Merge two configs for the same instance.
  # Later config values override earlier ones, except nil/empty doesn't override explicit values.
  defp merge_two_configs(earlier, later) do
    %{
      name: later.name,
      app: later.app,
      repo: merge_value(earlier.repo, later.repo),
      queues: merge_value(earlier.queues, later.queues),
      plugins: merge_value(earlier.plugins, later.plugins),
      insert_trigger: merge_value(earlier.insert_trigger, later.insert_trigger),
      engine: merge_value(earlier.engine, later.engine),
      # Keep the first file/line as the "primary" location
      file: earlier.file,
      line: earlier.line
    }
  end

  # nil or empty list doesn't override an explicit value
  defp merge_value(earlier, nil), do: earlier
  defp merge_value(earlier, []), do: earlier
  defp merge_value(_earlier, later), do: later

  @doc """
  Discovers all defined queues from config files.

  Returns a MapSet of queue names (atoms).
  """
  def discover_queues(root_path) do
    root_path
    |> discover_oban_configs()
    |> Enum.flat_map(& &1.queues)
    |> MapSet.new()
  end

  @doc """
  Checks if the project has Oban Pro as a dependency.

  Parses mix.exs files (including umbrella apps) to look for :oban_pro in deps.
  """
  def has_oban_pro?(root_path) do
    mix_files = [
      Path.join(root_path, "mix.exs")
      | Path.wildcard(Path.join(root_path, "apps/*/mix.exs"))
    ]

    Enum.any?(mix_files, fn mix_exs_path ->
      case File.read(mix_exs_path) do
        {:ok, content} -> content =~ ~r/:oban_pro\b/
        {:error, _} -> false
      end
    end)
  end

  defp extract_oban_configs_from_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        extract_oban_configs_from_content(content, file_path)

      {:error, _} ->
        []
    end
  end

  defp extract_oban_configs_from_content(content, file_path) do
    case Code.string_to_quoted(content, columns: true, line: 1) do
      {:ok, ast} ->
        extract_oban_configs_from_ast(ast, file_path)

      {:error, _} ->
        []
    end
  end

  defp extract_oban_configs_from_ast(ast, file_path) do
    {_ast, configs} =
      Macro.prewalk(ast, [], fn
        # Match: config :app, Oban, opts
        {:config, meta, [app, {:__aliases__, _, [:Oban]}, opts]} = node, acc
        when is_atom(app) and is_list(opts) ->
          config = parse_oban_config(app, opts, file_path, meta)
          {node, [config | acc]}

        # Match: config :app, Oban, opts (where Oban is an atom)
        {:config, meta, [app, Oban, opts]} = node, acc
        when is_atom(app) and is_list(opts) ->
          config = parse_oban_config(app, opts, file_path, meta)
          {node, [config | acc]}

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(configs)
  end

  defp parse_oban_config(app, opts, file_path, meta) do
    %{
      name: extract_name(opts),
      app: app,
      repo: extract_repo(opts),
      queues: extract_queues(opts),
      plugins: extract_plugins(opts),
      insert_trigger: extract_insert_trigger(opts),
      engine: extract_engine(opts),
      file: file_path,
      line: Keyword.get(meta, :line)
    }
  end

  defp extract_engine(opts) do
    case Keyword.get(opts, :engine) do
      {:__aliases__, _, parts} ->
        Module.concat(parts)

      engine when is_atom(engine) and not is_nil(engine) ->
        engine

      _ ->
        nil
    end
  end

  defp extract_name(opts) do
    case Keyword.get(opts, :name) do
      nil ->
        Oban

      {:__aliases__, _, parts} ->
        Module.concat(parts)

      name when is_atom(name) ->
        name

      _ ->
        Oban
    end
  end

  defp extract_repo(opts) do
    case Keyword.get(opts, :repo) do
      {:__aliases__, _, parts} ->
        Module.concat(parts)

      repo when is_atom(repo) and not is_nil(repo) ->
        repo

      _ ->
        nil
    end
  end

  defp extract_queues(opts) do
    opts
    |> Keyword.get(:queues, [])
    |> extract_queue_names()
  end

  defp extract_queue_names(list) when is_list(list) do
    Enum.flat_map(list, fn
      {queue_name, _limit} when is_atom(queue_name) -> [queue_name]
      _ -> []
    end)
  end

  defp extract_queue_names(_), do: []

  defp extract_plugins(opts) do
    opts
    |> Keyword.get(:plugins, [])
    |> extract_plugin_modules()
  end

  # Handle list concatenation: [static_plugins] ++ dynamic_expression
  # Extract plugins from the static part only
  defp extract_plugin_modules({:++, _, [left, _right]}) do
    extract_plugin_modules(left)
  end

  defp extract_plugin_modules(list) when is_list(list) do
    Enum.flat_map(list, fn
      # Module directly: Oban.Plugins.Pruner
      {:__aliases__, _, parts} ->
        [Module.concat(parts)]

      # Module with options: {Oban.Plugins.Pruner, [max_age: 60]}
      {{:__aliases__, _, parts}, _opts} ->
        [Module.concat(parts)]

      # Tuple form in AST: {:{}, _, [{:__aliases__, _, parts}, opts]}
      {:{}, _, [{:__aliases__, _, parts} | _rest]} ->
        [Module.concat(parts)]

      module when is_atom(module) ->
        [module]

      {module, _opts} when is_atom(module) ->
        [module]

      _ ->
        []
    end)
  end

  defp extract_plugin_modules(_), do: []

  defp extract_insert_trigger(opts) do
    case Keyword.fetch(opts, :insert_trigger) do
      {:ok, value} when is_boolean(value) -> value
      _ -> nil
    end
  end
end
