defmodule ObanDoctor.ConfigFile do
  @moduledoc """
  Handles loading and parsing of `.oban_doctor.exs` configuration files.
  """

  alias ObanDoctor.Config

  @config_filename ".oban_doctor.exs"

  @doc """
  Returns the path to the config file in the given directory.
  """
  def config_path(root_path) do
    Path.join(root_path, @config_filename)
  end

  @doc """
  Loads configuration from `.oban_doctor.exs` in the given directory.

  Returns `{:ok, config}` if found and valid, `{:error, reason}` otherwise.
  If no config file exists, returns a default config.
  """
  def load(root_path) do
    path = config_path(root_path)

    if File.exists?(path) do
      load_file(path)
    else
      {:ok, Config.new()}
    end
  end

  @doc """
  Loads configuration, raising on error.
  """
  def load!(root_path) do
    case load(root_path) do
      {:ok, config} -> config
      {:error, reason} -> raise "Failed to load config: #{reason}"
    end
  end

  defp load_file(path) do
    case Code.eval_file(path) do
      {keyword, _bindings} when is_list(keyword) ->
        {:ok, Config.from_keyword(keyword)}

      {other, _} ->
        {:error, "Config file must return a keyword list, got: #{inspect(other)}"}
    end
  rescue
    e in [CompileError, SyntaxError] ->
      {:error, "Config file has syntax error: #{Exception.message(e)}"}
  end

  @doc """
  Generates a default configuration file content.
  """
  def default_config_content(checks \\ []) do
    check_configs =
      checks
      |> Enum.map(fn check ->
        "    #{check.id()}: [enabled: true]"
      end)
      |> Enum.join(",\n")

    checks_section =
      if check_configs == "" do
        "    # No checks configured yet"
      else
        check_configs
      end

    """
    # ObanDoctor Configuration
    # See https://github.com/your-org/oban_doctor for documentation

    [
      # Configure individual checks
      # Set enabled: false to disable a check
      # Set severity: :warning to override default severity
      checks: [
    #{checks_section}
      ],

      # Exclude specific workers from all checks
      excluded_workers: [
        # MyApp.Workers.LegacyWorker
      ],

      # Exclude files matching these patterns
      excluded_files: [
        # "test/support/",
        # "_build/"
      ]
    ]
    """
  end
end
