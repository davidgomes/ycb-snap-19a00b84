defmodule ObanDoctor.CLI.OutputTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias ObanDoctor.CLI.Output
  alias ObanDoctor.Issue

  # Fake check module for testing
  defmodule FakeCheck do
    def description, do: "A fake check for testing"
  end

  defmodule AnotherCheck do
    def description, do: "Another check"
  end

  describe "print_issues/2 with :text format" do
    test "prints success message when no issues" do
      output = capture_io(fn -> Output.print_issues([]) end)

      assert output =~ "No issues found!"
    end

    test "prints issues grouped by severity" do
      issues = [
        Issue.new(
          check: FakeCheck,
          severity: :error,
          message: "Something is wrong",
          file: "lib/my_worker.ex",
          line: 10,
          meta: %{worker: MyApp.MyWorker}
        ),
        Issue.new(
          check: FakeCheck,
          severity: :warning,
          message: "Something might be wrong",
          file: "lib/other_worker.ex",
          line: 20,
          meta: %{worker: MyApp.OtherWorker}
        )
      ]

      output = capture_io(fn -> Output.print_issues(issues) end)

      assert output =~ "ERRORS (1)"
      assert output =~ "WARNINGS (1)"
      assert output =~ "Fake Check"
      assert output =~ "MyApp.MyWorker"
      assert output =~ "my_worker.ex:10"
      assert output =~ "other_worker.ex:20"
      assert output =~ "Summary:"
      assert output =~ "1 error"
      assert output =~ "1 warning"
    end

    test "limits issues per check by default" do
      issues =
        for i <- 1..5 do
          Issue.new(
            check: FakeCheck,
            severity: :error,
            message: "Error #{i}",
            file: "lib/worker_#{i}.ex",
            line: i,
            meta: %{worker: Module.concat(MyApp, "Worker#{i}")}
          )
        end

      output = capture_io(fn -> Output.print_issues(issues) end)

      assert output =~ "and 2 more (use --verbose to see all)"
    end

    test "shows all issues with verbose option" do
      issues =
        for i <- 1..5 do
          Issue.new(
            check: FakeCheck,
            severity: :error,
            message: "Error #{i}",
            file: "lib/worker_#{i}.ex",
            line: i,
            meta: %{worker: Module.concat(MyApp, "Worker#{i}")}
          )
        end

      output = capture_io(fn -> Output.print_issues(issues, verbose: true) end)

      refute output =~ "more (use --verbose"
      assert output =~ "worker_1.ex:1"
      assert output =~ "worker_5.ex:5"
    end

    test "handles issues with instance meta instead of worker" do
      issues = [
        Issue.new(
          check: FakeCheck,
          severity: :warning,
          message: "Config issue",
          file: "config/config.exs",
          line: 5,
          meta: %{instance: Oban}
        )
      ]

      output = capture_io(fn -> Output.print_issues(issues) end)

      assert output =~ "Oban"
      assert output =~ "config.exs:5"
    end

    test "handles issues without file" do
      issues = [
        Issue.new(
          check: FakeCheck,
          severity: :info,
          message: "Some info",
          file: nil,
          line: nil,
          meta: %{worker: MyApp.Worker}
        )
      ]

      output = capture_io(fn -> Output.print_issues(issues) end)

      assert output =~ "INFOS (1)"
      assert output =~ "MyApp.Worker"
    end

    test "handles issues with file but no line" do
      issues = [
        Issue.new(
          check: FakeCheck,
          severity: :error,
          message: "Error",
          file: "lib/worker.ex",
          line: nil,
          meta: %{worker: MyApp.Worker}
        )
      ]

      output = capture_io(fn -> Output.print_issues(issues) end)

      assert output =~ "worker.ex"
      refute output =~ "worker.ex:"
    end

    test "handles issues without worker or instance meta" do
      issues = [
        Issue.new(
          check: FakeCheck,
          severity: :error,
          message: "Error",
          file: "lib/something.ex",
          line: 1,
          meta: %{}
        )
      ]

      output = capture_io(fn -> Output.print_issues(issues) end)

      assert output =~ "Unknown"
    end

    test "groups issues by check within severity" do
      issues = [
        Issue.new(
          check: FakeCheck,
          severity: :error,
          message: "Error 1",
          file: "lib/a.ex",
          line: 1,
          meta: %{worker: MyApp.A}
        ),
        Issue.new(
          check: AnotherCheck,
          severity: :error,
          message: "Error 2",
          file: "lib/b.ex",
          line: 2,
          meta: %{worker: MyApp.B}
        ),
        Issue.new(
          check: FakeCheck,
          severity: :error,
          message: "Error 3",
          file: "lib/c.ex",
          line: 3,
          meta: %{worker: MyApp.C}
        )
      ]

      output = capture_io(fn -> Output.print_issues(issues) end)

      assert output =~ "[Fake Check] 2 issues"
      assert output =~ "[Another Check] 1 issue"
    end

    test "pluralizes correctly" do
      single_issue = [
        Issue.new(
          check: FakeCheck,
          severity: :error,
          message: "Error",
          file: "lib/a.ex",
          line: 1,
          meta: %{worker: MyApp.A}
        )
      ]

      output = capture_io(fn -> Output.print_issues(single_issue) end)

      assert output =~ "1 error"
      refute output =~ "1 errors"
    end
  end

  describe "print_issues/2 with :json format" do
    test "prints issues as JSON" do
      issues = [
        Issue.new(
          check: FakeCheck,
          severity: :error,
          message: "Something is wrong",
          file: "lib/my_worker.ex",
          line: 10,
          meta: %{worker: MyApp.MyWorker}
        )
      ]

      output = capture_io(fn -> Output.print_issues(issues, format: :json) end)

      decoded = Jason.decode!(output)
      assert is_list(decoded)
      assert length(decoded) == 1

      [issue] = decoded
      assert issue["severity"] == "error"
      assert issue["message"] == "Something is wrong"
      assert issue["file"] == "lib/my_worker.ex"
      assert issue["line"] == 10
      assert issue["meta"]["worker"] == "Elixir.MyApp.MyWorker"
    end

    test "prints empty array for no issues" do
      output = capture_io(fn -> Output.print_issues([], format: :json) end)

      assert Jason.decode!(output) == []
    end

    test "handles nested meta with tuples and lists" do
      issues = [
        Issue.new(
          check: FakeCheck,
          severity: :warning,
          message: "Warning",
          file: "lib/worker.ex",
          line: 1,
          meta: %{
            unique: [
              fields: [:args, :worker],
              period: {1, :hour}
            ]
          }
        )
      ]

      output = capture_io(fn -> Output.print_issues(issues, format: :json) end)

      decoded = Jason.decode!(output)
      [issue] = decoded
      assert issue["meta"]["unique"] == [["fields", ["args", "worker"]], ["period", [1, "hour"]]]
    end
  end

  describe "exit_code/2" do
    test "returns 0 when no issues" do
      assert Output.exit_code([]) == 0
    end

    test "returns 1 when there are errors" do
      issues = [
        Issue.new(
          check: FakeCheck,
          severity: :error,
          message: "Error",
          file: "lib/a.ex",
          line: 1,
          meta: %{}
        )
      ]

      assert Output.exit_code(issues) == 1
    end

    test "returns 0 for warnings without strict mode" do
      issues = [
        Issue.new(
          check: FakeCheck,
          severity: :warning,
          message: "Warning",
          file: "lib/a.ex",
          line: 1,
          meta: %{}
        )
      ]

      assert Output.exit_code(issues) == 0
    end

    test "returns 1 for warnings with strict mode" do
      issues = [
        Issue.new(
          check: FakeCheck,
          severity: :warning,
          message: "Warning",
          file: "lib/a.ex",
          line: 1,
          meta: %{}
        )
      ]

      assert Output.exit_code(issues, strict: true) == 1
    end

    test "returns 0 for info only" do
      issues = [
        Issue.new(
          check: FakeCheck,
          severity: :info,
          message: "Info",
          file: "lib/a.ex",
          line: 1,
          meta: %{}
        )
      ]

      assert Output.exit_code(issues) == 0
      assert Output.exit_code(issues, strict: true) == 0
    end
  end
end
