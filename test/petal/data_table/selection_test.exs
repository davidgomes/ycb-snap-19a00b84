defmodule PetalComponents.DataTable.SelectionTest do
  use ExUnit.Case, async: true

  alias PetalComponents.DataTable.Selection

  test "select adds keys once, keeping the existing order" do
    params = %{"op" => "select", "ids" => [3, 1, 3], "checked" => true}
    assert Selection.handle_op([1, 2], params) == [1, 2, 3]
  end

  test "deselect removes only the given keys" do
    params = %{"op" => "select", "ids" => [1, 3], "checked" => false}
    assert Selection.handle_op([1, 2, 3], params) == [2]
  end

  test "checked is a target state, so a repeated push is idempotent" do
    params = %{"op" => "select", "ids" => [2], "checked" => true}
    assert [1] |> Selection.handle_op(params) |> Selection.handle_op(params) == [1, 2]
  end

  test "a stringly checked flag (phx-value style) reads the same" do
    assert Selection.handle_op([], %{"op" => "select", "ids" => ["a"], "checked" => "true"}) ==
             ["a"]

    assert Selection.handle_op(["a"], %{"op" => "select", "ids" => ["a"], "checked" => "false"}) ==
             []
  end

  test "clear_selection empties it" do
    assert Selection.handle_op([1, 2], %{"op" => "clear_selection"}) == []
  end

  test "unknown ops and malformed payloads leave the selection unchanged" do
    assert Selection.handle_op([1], %{"op" => "sort", "field" => "name"}) == [1]
    assert Selection.handle_op([1], %{"op" => "select", "ids" => "1", "checked" => true}) == [1]
    assert Selection.handle_op([1], %{"op" => "select", "ids" => [2]}) == [1]
  end
end
