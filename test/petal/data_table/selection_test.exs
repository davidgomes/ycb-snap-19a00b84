defmodule PetalComponents.DataTable.SelectionTest do
  use ExUnit.Case, async: true

  alias PetalComponents.DataTable.Selection

  describe "new/0" do
    test "is an empty set" do
      assert Selection.new() == MapSet.new()
    end
  end

  describe "normalize/1" do
    test "stringifies ids from any enumerable, MapSet or list, integers or strings" do
      assert Selection.normalize([1, 2, "3"]) == MapSet.new(["1", "2", "3"])
      assert Selection.normalize(MapSet.new([1, 2])) == MapSet.new(["1", "2"])
      assert Selection.normalize([]) == MapSet.new()
    end
  end

  describe "handle_op/2 - toggle" do
    test "adds an unselected id" do
      assert Selection.handle_op(MapSet.new(), %{"op" => "toggle", "id" => "1"}) ==
               MapSet.new(["1"])
    end

    test "removes an already-selected id" do
      assert Selection.handle_op(MapSet.new(["1", "2"]), %{"op" => "toggle", "id" => "1"}) ==
               MapSet.new(["2"])
    end

    test "compares ids as strings regardless of the payload's type" do
      assert Selection.handle_op(MapSet.new(["1"]), %{"op" => "toggle", "id" => 1}) ==
               MapSet.new()
    end
  end

  describe "handle_op/2 - toggle_page" do
    test "selects every page id when not all are already selected" do
      selected = MapSet.new(["1"])
      result = Selection.handle_op(selected, %{"op" => "toggle_page", "ids" => ["1", "2", "3"]})
      assert result == MapSet.new(["1", "2", "3"])
    end

    test "deselects every page id once all of them are selected - the tri-state header's own click" do
      selected = MapSet.new(["1", "2", "3", "9"])
      result = Selection.handle_op(selected, %{"op" => "toggle_page", "ids" => ["1", "2", "3"]})
      assert result == MapSet.new(["9"])
    end

    test "leaves selections outside the page untouched" do
      selected = MapSet.new(["9"])
      result = Selection.handle_op(selected, %{"op" => "toggle_page", "ids" => ["1", "2"]})
      assert result == MapSet.new(["1", "2", "9"])
    end
  end

  describe "handle_op/2 - clear and unknown ops" do
    test "clear empties the selection" do
      assert Selection.handle_op(MapSet.new(["1", "2"]), %{"op" => "clear"}) == MapSet.new()
    end

    test "an unknown op leaves the selection unchanged" do
      selected = MapSet.new(["1"])
      assert Selection.handle_op(selected, %{"op" => "bogus"}) == selected
    end
  end

  describe "page_state/2" do
    test "none when the page has no ids" do
      assert Selection.page_state(MapSet.new(["1"]), []) == :none
    end

    test "none when nothing on the page is selected" do
      assert Selection.page_state(MapSet.new(["9"]), ["1", "2"]) == :none
    end

    test "some when part of the page is selected" do
      assert Selection.page_state(MapSet.new(["1"]), ["1", "2"]) == :some
    end

    test "all when every page id is selected (extra selections elsewhere don't matter)" do
      assert Selection.page_state(MapSet.new(["1", "2", "9"]), ["1", "2"]) == :all
    end
  end
end
