defmodule LineUp do
  @doc """
  Given a name and a number, return a sentence with the number as an ordinal numeral.
  """
  @spec format(name :: String.t(), number :: pos_integer()) :: String.t()
  def format(name, number) do
    "#{name}, you are the #{number}#{suffix(number)} customer we serve today. Thank you!"
  end

  defp suffix(number) when rem(number, 100) in 11..13, do: "th"

  defp suffix(number) do
    case rem(number, 10) do
      1 -> "st"
      2 -> "nd"
      3 -> "rd"
      _ -> "th"
    end
  end
end
