defmodule PetalComponents.DataTable.SelectionTest do
  use ExUnit.Case, async: true

  alias PetalComponents.DataTable.Selection

  test "select toggles one id and keeps the caller's type on the way out" do
    assert Selection.apply([1, 2], %{"op" => "select", "id" => "2"}) == [1]
    assert Selection.apply([1], %{"op" => "select", "id" => "3"}) == [1, "3"]
  end

  test "select_page adds or drops only the page's ids" do
    ids = Jason.encode!(["1", "2"])

    assert Selection.apply([3], %{"op" => "select_page", "mode" => "all", "ids" => ids}) ==
             [3, "1", "2"]

    assert Selection.apply([1, "2", 3], %{
             "op" => "select_page",
             "mode" => "none",
             "ids" => ids
           }) == [3]
  end

  test "clear_selection empties the list and other ops pass through" do
    assert Selection.apply([1], %{"op" => "clear_selection"}) == []
    assert Selection.apply([1], %{"op" => "sort", "field" => "name"}) == [1]
  end
end
