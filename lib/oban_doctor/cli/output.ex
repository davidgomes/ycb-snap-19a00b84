defmodule ObanDoctor.CLI.Output do
  @moduledoc """
  Handles formatting and displaying check results.
  """

  alias ObanDoctor.Issue

  @colors %{
    error: :red,
    warning: :yellow,
    info: :cyan,
    success: :green,
    reset: :reset
  }

  @doc """
  Prints issues to the console.
  """
  def print_issues(issues, opts \\ []) do
    format = Keyword.get(opts, :format, :text)

    case format do
      :json -> print_json(issues)
      :text -> print_text(issues)
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
          meta: issue.meta
        }
      end)

    IO.puts(JSON.encode!(data))
  end

  defp print_text([]) do
    IO.puts(colorize("No issues found!", :success))
  end

  defp print_text(issues) do
    issues
    |> Enum.group_by(& &1.severity)
    |> Enum.each(fn {severity, severity_issues} ->
      IO.puts("")

      IO.puts(
        colorize("#{String.upcase(to_string(severity))}S (#{length(severity_issues)})", severity)
      )

      IO.puts(String.duplicate("-", 60))

      Enum.each(severity_issues, &print_issue/1)
    end)

    print_summary(issues)
  end

  defp print_issue(issue) do
    location = format_location(issue.file, issue.line)
    check_name = Issue.check_name(issue)

    IO.puts("")
    IO.puts("  #{colorize("[#{check_name}]", issue.severity)}")
    IO.puts("  #{issue.message}")

    if location do
      IO.puts("  #{colorize(location, :info)}")
    end
  end

  defp format_location(nil, _), do: nil
  defp format_location(file, nil), do: file
  defp format_location(file, line), do: "#{file}:#{line}"

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

    IO.puts("Found: #{Enum.join(parts, ", ")}")
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
