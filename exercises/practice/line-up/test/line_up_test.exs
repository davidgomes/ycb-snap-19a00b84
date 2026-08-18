defmodule LineUpTest do
  use ExUnit.Case

  # @tag :pending
  test "format smallest non-exceptional ordinal numeral 4" do
    name = "Gianna"
    number = 4
    expected = "Gianna, you are the 4th customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format greatest single digit non-exceptional ordinal numeral 9" do
    name = "Maarten"
    number = 9
    expected = "Maarten, you are the 9th customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format non-exceptional ordinal numeral 5" do
    name = "Petronila"
    number = 5
    expected = "Petronila, you are the 5th customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format non-exceptional ordinal numeral 6" do
    name = "Attakullakulla"
    number = 6
    expected = "Attakullakulla, you are the 6th customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format non-exceptional ordinal numeral 7" do
    name = "Kate"
    number = 7
    expected = "Kate, you are the 7th customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format non-exceptional ordinal numeral 8" do
    name = "Maximiliano"
    number = 8
    expected = "Maximiliano, you are the 8th customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 1" do
    name = "Mary"
    number = 1
    expected = "Mary, you are the 1st customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 2" do
    name = "Haruto"
    number = 2
    expected = "Haruto, you are the 2nd customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 3" do
    name = "Henriette"
    number = 3
    expected = "Henriette, you are the 3rd customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format smallest two digit non-exceptional ordinal numeral 10" do
    name = "Alvarez"
    number = 10
    expected = "Alvarez, you are the 10th customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format non-exceptional ordinal numeral 11" do
    name = "Jacqueline"
    number = 11
    expected = "Jacqueline, you are the 11th customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format non-exceptional ordinal numeral 12" do
    name = "Juan"
    number = 12
    expected = "Juan, you are the 12th customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format non-exceptional ordinal numeral 13" do
    name = "Patricia"
    number = 13
    expected = "Patricia, you are the 13th customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 21" do
    name = "Washi"
    number = 21
    expected = "Washi, you are the 21st customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 22 ending in nd even though it is a multiple of 11" do
    name = "Ingrid"
    number = 22
    expected = "Ingrid, you are the 22nd customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 33 ending in rd even though it is a multiple of 11" do
    name = "Mario"
    number = 33
    expected = "Mario, you are the 33rd customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 52 ending in nd even though it is a multiple of 13" do
    name = "Quentin"
    number = 52
    expected = "Quentin, you are the 52nd customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 62" do
    name = "Nayra"
    number = 62
    expected = "Nayra, you are the 62nd customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format non-exceptional ordinal numeral 72 ending in nd even though it is a multiple of 12" do
    name = "Ugo"
    number = 72
    expected = "Ugo, you are the 72nd customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 91 ending in st even though it is a multiple of 13" do
    name = "Boris"
    number = 91
    expected = "Boris, you are the 91st customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 100" do
    name = "John"
    number = 100
    expected = "John, you are the 100th customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 101" do
    name = "Zeinab"
    number = 101
    expected = "Zeinab, you are the 101st customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format non-exceptional ordinal numeral 112" do
    name = "Knud"
    number = 112
    expected = "Knud, you are the 112th customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 123" do
    name = "Yma"
    number = 123
    expected = "Yma, you are the 123rd customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end

  @tag :pending
  test "format large number 972 ending in nd even though it is a multiple of 12" do
    name = "Elias"
    number = 972
    expected = "Elias, you are the 972nd customer we serve today. Thank you!"
    assert LineUp.format(name, number) == expected
  end
end
