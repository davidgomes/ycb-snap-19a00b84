defmodule GradingClient.GradedCellTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO
  import Kino.Test

  alias GradingClient.GradedCell

  setup :configure_livebook_bridge

  @attrs %{
    "module_id" => "OWASP",
    "question_id" => 2,
    "source" => "# CHANGE ME\nvulnerable_dependency = :vulnerable_dependency"
  }

  test "generates source that grades the result of the editor code" do
    {_kino, source} = start_smart_cell!(GradedCell, @attrs)

    assert source == """
           result = vulnerable_dependency = :vulnerable_dependency
           GradingClient.grade(result, "OWASP", 2)\
           """
  end

  test "keeps grading the same question when the editor source changes" do
    {kino, _source} = start_smart_cell!(GradedCell, @attrs)

    push_smart_cell_editor_source(kino, "vulnerable_dependency = :plug")

    assert_smart_cell_update(
      kino,
      %{"module_id" => "OWASP", "question_id" => 2, "source" => "vulnerable_dependency = :plug"},
      source
    )

    assert capture_io(fn -> Code.eval_string(source) end) =~ "Correct!"
  end

  test "sends the graded question to the client" do
    {kino, _source} = start_smart_cell!(GradedCell, @attrs)

    assert connect(kino) == %{module_id: "OWASP", question_id: 2}
  end

  test "leaves source with syntax errors as-is, so evaluation reports them" do
    attrs = %{@attrs | "source" => "vulnerable_dependency = "}

    assert GradedCell.to_source(attrs) == "vulnerable_dependency = "
  end
end
