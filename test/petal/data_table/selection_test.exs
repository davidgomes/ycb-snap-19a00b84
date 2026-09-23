defmodule PetalComponents.DataTable.SelectionTest do
  use ExUnit.Case, async: true

  alias PetalComponents.DataTable.Selection

  test "new/1 normalizes ids to strings" do
    assert Selection.new([1, "2"]) == MapSet.new(["1", "2"])
    assert Selection.new(nil) == MapSet.new()
  end

  test "select toggles one id, whatever its type" do
    selected = Selection.handle_op([], %{"op" => "select", "id" => 3})
    assert selected == MapSet.new(["3"])
    assert Selection.handle_op(selected, %{"op" => "select", "id" => "3"}) == MapSet.new()
  end

  test "select_page adds or removes the page's ids, leaving other pages alone" do
    selected = MapSet.new(["9"])

    added =
      Selection.handle_op(selected, %{
        "op" => "select_page",
        "ids" => ["1", "2"],
        "checked" => true
      })

    assert added == MapSet.new(["1", "2", "9"])

    removed =
      Selection.handle_op(added, %{"op" => "select_page", "ids" => ["1", "2"], "checked" => false})

    assert removed == MapSet.new(["9"])

    assert Selection.handle_op(selected, %{
             "op" => "select_page",
             "ids" => ["1"],
             "checked" => "true"
           }) == MapSet.new(["1", "9"])
  end

  test "clear_selection empties; foreign ops leave the selection unchanged" do
    selected = MapSet.new(["1"])
    assert Selection.handle_op(selected, %{"op" => "clear_selection"}) == MapSet.new()
    assert Selection.handle_op(selected, %{"op" => "sort", "field" => "name"}) == selected
    assert Selection.handle_op(selected, %{"op" => "select_page", "ids" => "1"}) == selected
  end

  test "page_state/2 reads the tri-state header over one page" do
    assert Selection.page_state([], ["1", "2"]) == :none
    assert Selection.page_state(["1"], [1, 2]) == :some
    assert Selection.page_state(["1", "2", "7"], [1, 2]) == :all
    assert Selection.page_state(["1"], []) == :none
  end
end
