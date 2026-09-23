defmodule LineUp do
  @doc """
  Given a customer's name and their number in line,
  return a sentence using that number as an ordinal numeral.
  """
  @spec format(name :: String.t(), number :: pos_integer()) :: String.t()
  def format(name, number) do
    "#{name}, you are the #{number}#{suffix(number)} customer we serve today. Thank you!"
  end

  defp suffix(number) when rem(number, 100) in [11, 12, 13], do: "th"
  defp suffix(number) when rem(number, 10) == 1, do: "st"
  defp suffix(number) when rem(number, 10) == 2, do: "nd"
  defp suffix(number) when rem(number, 10) == 3, do: "rd"
  defp suffix(_number), do: "th"
end
