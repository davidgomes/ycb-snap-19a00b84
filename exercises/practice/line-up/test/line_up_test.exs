defmodule LineUpTest do
  use ExUnit.Case

  # Names are chosen without Unicode characters to keep the exercise simple.
  #
  # The tests are ordered starting with small regular cases and coming to
  # bigger and irregular cases later on.

  test "format smallest non-exceptional ordinal numeral 4" do
    name = "Gianna"
    number = 4
    output = LineUp.format(name, number)
    expected = "Gianna, you are the 4th customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format greatest single digit non-exceptional ordinal numeral 9" do
    name = "Maarten"
    number = 9
    output = LineUp.format(name, number)
    expected = "Maarten, you are the 9th customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format non-exceptional ordinal numeral 5" do
    name = "Petronila"
    number = 5
    output = LineUp.format(name, number)
    expected = "Petronila, you are the 5th customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format non-exceptional ordinal numeral 6" do
    name = "Attakullakulla"
    number = 6
    output = LineUp.format(name, number)
    expected = "Attakullakulla, you are the 6th customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format non-exceptional ordinal numeral 7" do
    name = "Kate"
    number = 7
    output = LineUp.format(name, number)
    expected = "Kate, you are the 7th customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format non-exceptional ordinal numeral 8" do
    name = "Maximiliano"
    number = 8
    output = LineUp.format(name, number)
    expected = "Maximiliano, you are the 8th customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 1" do
    name = "Mary"
    number = 1
    output = LineUp.format(name, number)
    expected = "Mary, you are the 1st customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 2" do
    name = "Haruto"
    number = 2
    output = LineUp.format(name, number)
    expected = "Haruto, you are the 2nd customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 3" do
    name = "Henriette"
    number = 3
    output = LineUp.format(name, number)
    expected = "Henriette, you are the 3rd customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format smallest two digit non-exceptional ordinal numeral 10" do
    name = "Alvarez"
    number = 10
    output = LineUp.format(name, number)
    expected = "Alvarez, you are the 10th customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format non-exceptional ordinal numeral 11" do
    name = "Jacqueline"
    number = 11
    output = LineUp.format(name, number)
    expected = "Jacqueline, you are the 11th customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format non-exceptional ordinal numeral 12" do
    name = "Juan"
    number = 12
    output = LineUp.format(name, number)
    expected = "Juan, you are the 12th customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format non-exceptional ordinal numeral 13" do
    name = "Patricia"
    number = 13
    output = LineUp.format(name, number)
    expected = "Patricia, you are the 13th customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 21" do
    name = "Washi"
    number = 21
    output = LineUp.format(name, number)
    expected = "Washi, you are the 21st customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 22 ending in nd even though it is a multiple of 11" do
    name = "Ingrid"
    number = 22
    output = LineUp.format(name, number)
    expected = "Ingrid, you are the 22nd customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 33 ending in rd even though it is a multiple of 11" do
    name = "Mario"
    number = 33
    output = LineUp.format(name, number)
    expected = "Mario, you are the 33rd customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 52 ending in nd even though it is a multiple of 13" do
    name = "Quentin"
    number = 52
    output = LineUp.format(name, number)
    expected = "Quentin, you are the 52nd customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 62" do
    name = "Nayra"
    number = 62
    output = LineUp.format(name, number)
    expected = "Nayra, you are the 62nd customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format non-exceptional ordinal numeral 72 ending in nd even though it is a multiple of 12" do
    name = "Ugo"
    number = 72
    output = LineUp.format(name, number)
    expected = "Ugo, you are the 72nd customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 91 ending in st even though it is a multiple of 13" do
    name = "Boris"
    number = 91
    output = LineUp.format(name, number)
    expected = "Boris, you are the 91st customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 100" do
    name = "John"
    number = 100
    output = LineUp.format(name, number)
    expected = "John, you are the 100th customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 101" do
    name = "Zeinab"
    number = 101
    output = LineUp.format(name, number)
    expected = "Zeinab, you are the 101st customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format non-exceptional ordinal numeral 112" do
    name = "Knud"
    number = 112
    output = LineUp.format(name, number)
    expected = "Knud, you are the 112th customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format exceptional ordinal numeral 123" do
    name = "Yma"
    number = 123
    output = LineUp.format(name, number)
    expected = "Yma, you are the 123rd customer we serve today. Thank you!"

    assert output == expected
  end

  @tag :pending
  test "format large number 972 ending in nd even though it is a multiple of 12" do
    name = "Elias"
    number = 972
    output = LineUp.format(name, number)
    expected = "Elias, you are the 972nd customer we serve today. Thank you!"

    assert output == expected
  end
end
