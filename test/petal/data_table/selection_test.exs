defmodule PetalComponents.DataTable.SelectionTest do
  use ExUnit.Case, async: true

  alias PetalComponents.DataTable.Selection

  @page [1, 2, 3]

  describe "handle_op/3 select" do
    test "checking a row adds its id, resolved back to the page's own type" do
      selected =
        Selection.handle_op([], %{"op" => "select", "id" => "2", "checked" => "true"}, ids: @page)

      assert selected == [2]
    end

    test "unchecking removes it, whichever type the selection holds" do
      params = %{"op" => "select", "id" => "2", "checked" => "false"}

      assert Selection.handle_op([1, 2], params, ids: @page) == [1]
      assert Selection.handle_op(["1", "2"], params, ids: @page) == ["1"]
    end

    test "checking an already selected row is a no-op, order preserved" do
      params = %{"op" => "select", "id" => "1", "checked" => "true"}
      assert Selection.handle_op([3, 1], params, ids: @page) == [3, 1]
    end

    test "an id the page does not hold is dropped" do
      params = %{"op" => "select", "id" => "99", "checked" => "true"}
      assert Selection.handle_op([1], params, ids: @page) == [1]
      assert Selection.handle_op([1], params, []) == [1]
    end

    test "a form-posted checkbox reads as checked too" do
      params = %{"op" => "select", "id" => "1", "checked" => "on"}
      assert Selection.handle_op([], params, ids: @page) == [1]
    end
  end

  describe "handle_op/3 select_page" do
    test "checking unions the page in without disturbing off-page picks" do
      params = %{"op" => "select_page", "checked" => "true"}
      assert Selection.handle_op([9, 2], params, ids: @page) == [9, 2, 1, 3]
    end

    test "unchecking subtracts only the page" do
      params = %{"op" => "select_page", "checked" => "false"}
      assert Selection.handle_op([9, 2, 3], params, ids: @page) == [9]
    end

    test "without ids there is no page to act on" do
      assert Selection.handle_op([9], %{"op" => "select_page", "checked" => "true"}, []) == [9]
    end
  end

  test "clear_selection empties everything" do
    assert Selection.handle_op([1, 2], %{"op" => "clear_selection"}, ids: @page) == []
  end

  test "unknown ops leave the selection alone" do
    assert Selection.handle_op([1], %{"op" => "drop_table"}, ids: @page) == [1]
    assert Selection.handle_op([1], %{}, ids: @page) == [1]
  end

  describe "member?/2" do
    test "compares as strings, so param ids line up with integer row ids" do
      assert Selection.member?([1, 2], "2")
      assert Selection.member?(["2"], 2)
      refute Selection.member?([1, 2], "3")
      refute Selection.member?([], 1)
    end
  end
end
