defmodule LineUpTest do
  use ExUnit.Case

  # @tag :pending
  test "format Mary with 1" do
    assert LineUp.format("Mary", 1) ==
             "Mary, you are the 1st customer we serve today. Thank you!"
  end

  @tag :pending
  test "format Luciana with 2" do
    assert LineUp.format("Luciana", 2) ==
             "Luciana, you are the 2nd customer we serve today. Thank you!"
  end

  @tag :pending
  test "format Hamza with 3" do
    assert LineUp.format("Hamza", 3) ==
             "Hamza, you are the 3rd customer we serve today. Thank you!"
  end

  @tag :pending
  test "format Jonathan with 4" do
    assert LineUp.format("Jonathan", 4) ==
             "Jonathan, you are the 4th customer we serve today. Thank you!"
  end

  @tag :pending
  test "format Dahir with 9" do
    assert LineUp.format("Dahir", 9) ==
             "Dahir, you are the 9th customer we serve today. Thank you!"
  end

  @tag :pending
  test "format Rashid with 11" do
    assert LineUp.format("Rashid", 11) ==
             "Rashid, you are the 11th customer we serve today. Thank you!"
  end

  @tag :pending
  test "format Hesper with 12" do
    assert LineUp.format("Hesper", 12) ==
             "Hesper, you are the 12th customer we serve today. Thank you!"
  end

  @tag :pending
  test "format Mandla with 13" do
    assert LineUp.format("Mandla", 13) ==
             "Mandla, you are the 13th customer we serve today. Thank you!"
  end

  @tag :pending
  test "format Kjell with 14" do
    assert LineUp.format("Kjell", 14) ==
             "Kjell, you are the 14th customer we serve today. Thank you!"
  end

  @tag :pending
  test "format Joyce with 21" do
    assert LineUp.format("Joyce", 21) ==
             "Joyce, you are the 21st customer we serve today. Thank you!"
  end

  @tag :pending
  test "format Mateo with 22" do
    assert LineUp.format("Mateo", 22) ==
             "Mateo, you are the 22nd customer we serve today. Thank you!"
  end

  @tag :pending
  test "format Tae with 23" do
    assert LineUp.format("Tae", 23) ==
             "Tae, you are the 23rd customer we serve today. Thank you!"
  end

  @tag :pending
  test "format Roya with 93" do
    assert LineUp.format("Roya", 93) ==
             "Roya, you are the 93rd customer we serve today. Thank you!"
  end

  @tag :pending
  test "format Hamid with 101" do
    assert LineUp.format("Hamid", 101) ==
             "Hamid, you are the 101st customer we serve today. Thank you!"
  end

  @tag :pending
  test "format Marek with 102" do
    assert LineUp.format("Marek", 102) ==
             "Marek, you are the 102nd customer we serve today. Thank you!"
  end

  @tag :pending
  test "format Zeynep with 111" do
    assert LineUp.format("Zeynep", 111) ==
             "Zeynep, you are the 111th customer we serve today. Thank you!"
  end

  @tag :pending
  test "format Kenji with 112" do
    assert LineUp.format("Kenji", 112) ==
             "Kenji, you are the 112th customer we serve today. Thank you!"
  end

  @tag :pending
  test "format Kwadwo with 113" do
    assert LineUp.format("Kwadwo", 113) ==
             "Kwadwo, you are the 113th customer we serve today. Thank you!"
  end

  @tag :pending
  test "format Dima with 162" do
    assert LineUp.format("Dima", 162) ==
             "Dima, you are the 162nd customer we serve today. Thank you!"
  end

  @tag :pending
  test "format Nina with 263" do
    assert LineUp.format("Nina", 263) ==
             "Nina, you are the 263rd customer we serve today. Thank you!"
  end

  @tag :pending
  test "format Irene with 999" do
    assert LineUp.format("Irene", 999) ==
             "Irene, you are the 999th customer we serve today. Thank you!"
  end
end
