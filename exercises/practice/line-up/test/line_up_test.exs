defmodule LineUpTest do
  use ExUnit.Case

  # @tag :pending
  test "format 1st ordinal numeral" do
    assert LineUp.format("Mary", 1) ==
             "Mary, you are the 1st customer we serve today. Thank you!"
  end

  @tag :pending
  test "format 2nd ordinal numeral" do
    assert LineUp.format("Haruto", 2) ==
             "Haruto, you are the 2nd customer we serve today. Thank you!"
  end

  @tag :pending
  test "format 3rd ordinal numeral" do
    assert LineUp.format("Henriette", 3) ==
             "Henriette, you are the 3rd customer we serve today. Thank you!"
  end

  @tag :pending
  test "format 4th ordinal numeral" do
    assert LineUp.format("Alireza", 4) ==
             "Alireza, you are the 4th customer we serve today. Thank you!"
  end

  @tag :pending
  test "format 9th ordinal numeral" do
    assert LineUp.format("Jose", 9) ==
             "Jose, you are the 9th customer we serve today. Thank you!"
  end

  @tag :pending
  test "format 11th ordinal numeral" do
    assert LineUp.format("Jamie", 11) ==
             "Jamie, you are the 11th customer we serve today. Thank you!"
  end

  @tag :pending
  test "format 12th ordinal numeral" do
    assert LineUp.format("John", 12) ==
             "John, you are the 12th customer we serve today. Thank you!"
  end

  @tag :pending
  test "format 13th ordinal numeral" do
    assert LineUp.format("Tamar", 13) ==
             "Tamar, you are the 13th customer we serve today. Thank you!"
  end

  @tag :pending
  test "format 21st ordinal numeral" do
    assert LineUp.format("Maria", 21) ==
             "Maria, you are the 21st customer we serve today. Thank you!"
  end

  @tag :pending
  test "format 22nd ordinal numeral" do
    assert LineUp.format("Kwame", 22) ==
             "Kwame, you are the 22nd customer we serve today. Thank you!"
  end

  @tag :pending
  test "format 23rd ordinal numeral" do
    assert LineUp.format("Lindiwe", 23) ==
             "Lindiwe, you are the 23rd customer we serve today. Thank you!"
  end

  @tag :pending
  test "format 100th ordinal numeral" do
    assert LineUp.format("Leila", 100) ==
             "Leila, you are the 100th customer we serve today. Thank you!"
  end

  @tag :pending
  test "format 101st ordinal numeral" do
    assert LineUp.format("Ali", 101) ==
             "Ali, you are the 101st customer we serve today. Thank you!"
  end

  @tag :pending
  test "format 111th ordinal numeral" do
    assert LineUp.format("Kofi", 111) ==
             "Kofi, you are the 111th customer we serve today. Thank you!"
  end

  @tag :pending
  test "format 112th ordinal numeral" do
    assert LineUp.format("Aditi", 112) ==
             "Aditi, you are the 112th customer we serve today. Thank you!"
  end

  @tag :pending
  test "format 113th ordinal numeral" do
    assert LineUp.format("Mei", 113) ==
             "Mei, you are the 113th customer we serve today. Thank you!"
  end

  @tag :pending
  test "format 162nd ordinal numeral" do
    assert LineUp.format("Dahir", 162) ==
             "Dahir, you are the 162nd customer we serve today. Thank you!"
  end

  @tag :pending
  test "format 999th ordinal numeral" do
    assert LineUp.format("Yaʻqūb", 999) ==
             "Yaʻqūb, you are the 999th customer we serve today. Thank you!"
  end
end
