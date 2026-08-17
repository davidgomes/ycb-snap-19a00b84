defmodule ObanDoctor.CLI.Output do
  @moduledoc """
  Handles formatting and displaying check results.
  """

  @colors %{
    error: :red,
    warning: :yellow,
    info: :cyan,
    success: :green,
    reset: :reset
  }

  @default_max_per_check 3

  @doc """
  Prints issues to the console.

  ## Options

    * `:format` - Output format: `:text` (default) or `:json`
    * `:verbose` - Show all issues (default: false, shows first 3 per check)
  """
  def print_issues(issues, opts \\ []) do
    format = Keyword.get(opts, :format, :text)

    case format do
      :json -> print_json(issues)
      :text -> print_text(issues, opts)
    end
  end

  defp print_json(issues) do
    data =
      Enum.map(issues, fn issue ->
        %{
          check: to_string(issue.check),
          severity: to_string(issue.severity),
          message: issue.message,
          file: issue.file,
          line: issue.line,
          meta: json_safe(issue.meta)
        }
      end)

    IO.puts(JSON.encode!(data))
  end

  # Converts values to JSON-safe types (handles atoms, tuples, etc.)
  defp json_safe(value) when is_map(value) do
    Map.new(value, fn {k, v} -> {to_string(k), json_safe(v)} end)
  end

  defp json_safe(value) when is_list(value) do
    Enum.map(value, &json_safe/1)
  end

  defp json_safe(value) when is_tuple(value) do
    value |> Tuple.to_list() |> json_safe()
  end

  defp json_safe(value) when is_atom(value), do: to_string(value)
  defp json_safe(value), do: value

  defp print_text([], _opts) do
    IO.puts(colorize("No issues found!", :success))
  end

  defp print_text(issues, opts) do
    verbose = Keyword.get(opts, :verbose, false)
    max_per_check = if verbose, do: :infinity, else: @default_max_per_check

    issues
    |> Enum.group_by(& &1.severity)
    |> Enum.sort_by(fn {sev, _} -> severity_order(sev) end)
    |> Enum.each(fn {severity, severity_issues} ->
      IO.puts("")

      IO.puts(
        colorize("#{String.upcase(to_string(severity))}S (#{length(severity_issues)})", severity)
      )

      IO.puts(String.duplicate("=", 60))

      severity_issues
      |> Enum.group_by(& &1.check)
      |> Enum.sort_by(fn {_check, issues} -> -length(issues) end)
      |> Enum.each(fn {check, check_issues} ->
        print_check_group(check, check_issues, severity, max_per_check, verbose)
      end)
    end)

    print_summary(issues)
  end

  defp severity_order(:error), do: 0
  defp severity_order(:warning), do: 1
  defp severity_order(:info), do: 2

  defp print_check_group(check, issues, severity, max, verbose) do
    count = length(issues)
    check_name = check_name_from_module(check)
    description = check.description()

    IO.puts("")
    IO.puts(colorize("┃ [#{check_name}] #{count} #{pluralize("issue", count)}", severity))
    IO.puts(colorize("┃ #{description}", :reset))
    IO.puts("┃")

    {to_show, remaining} =
      if max == :infinity do
        {issues, []}
      else
        Enum.split(issues, max)
      end

    Enum.each(to_show, &print_compact_issue/1)

    if remaining != [] do
      IO.puts("┃   ... and #{length(remaining)} more (use --verbose to see all)")
    end

    if verbose do
      print_how_to_fix(check)
    end
  end

  defp print_how_to_fix(check) do
    case extract_how_to_fix(check) do
      nil ->
        :ok

      how_to_fix ->
        IO.puts("┃")
        IO.puts(colorize("┃ How to fix:", :success))

        how_to_fix
        |> String.split("\n")
        |> Enum.each(fn line ->
          IO.puts("┃   #{line}")
        end)
    end
  end

  defp extract_how_to_fix(check) do
    case Code.fetch_docs(check) do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} ->
        extract_section(moduledoc, "How to fix")

      _ ->
        nil
    end
  end

  defp extract_section(doc, section_title) do
    # Match "## Section Title" followed by content until next "##" or end
    pattern = ~r/## #{Regex.escape(section_title)}\s*\n(.*?)(?=\n## |\n\z|\z)/s

    case Regex.run(pattern, doc) do
      [_, content] ->
        content
        |> String.trim()
        |> strip_code_fences()

      _ ->
        nil
    end
  end

  # Remove markdown code fences but keep the code content
  defp strip_code_fences(text) do
    text
    |> String.replace(~r/```\w*\n?/, "")
    |> String.trim()
  end

  defp print_compact_issue(issue) do
    module_name = format_module_name(issue)
    file_ref = format_short_location(issue.file, issue.line)

    IO.puts("┃   #{module_name}  #{file_ref}")
  end

  defp format_module_name(issue) do
    cond do
      worker = issue.meta[:worker] ->
        worker
        |> to_string()
        |> String.replace(~r/^Elixir\./, "")

      instance = issue.meta[:instance] ->
        inspect(instance)

      true ->
        "Unknown"
    end
  end

  defp format_short_location(nil, _), do: ""
  defp format_short_location(file, nil), do: Path.basename(file)

  defp format_short_location(file, line) do
    "#{Path.basename(file)}:#{line}"
  end

  defp check_name_from_module(check) do
    check
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp print_summary(issues) do
    errors = Enum.count(issues, &(&1.severity == :error))
    warnings = Enum.count(issues, &(&1.severity == :warning))
    infos = Enum.count(issues, &(&1.severity == :info))

    IO.puts("")
    IO.puts(String.duplicate("=", 60))

    parts =
      [
        {errors, "error", :error},
        {warnings, "warning", :warning},
        {infos, "info", :info}
      ]
      |> Enum.filter(fn {count, _, _} -> count > 0 end)
      |> Enum.map(fn {count, label, color} ->
        colorize("#{count} #{pluralize(label, count)}", color)
      end)

    IO.puts("Summary: #{Enum.join(parts, ", ")}")
  end

  defp pluralize(word, 1), do: word
  defp pluralize(word, _), do: word <> "s"

  defp colorize(text, color_key) do
    color = Map.get(@colors, color_key, :reset)
    IO.ANSI.format([color, text, :reset]) |> IO.chardata_to_string()
  end

  @doc """
  Returns an appropriate exit code based on issues found.
  """
  def exit_code(issues, opts \\ []) do
    strict = Keyword.get(opts, :strict, false)

    has_errors = Enum.any?(issues, &(&1.severity == :error))
    has_warnings = Enum.any?(issues, &(&1.severity == :warning))

    cond do
      has_errors -> 1
      strict and has_warnings -> 1
      true -> 0
    end
  end
end
