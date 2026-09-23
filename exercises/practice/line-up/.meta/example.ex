defmodule LineUp do
  @doc """
  Format a sentence for a customer with their name and ordinal number in line.
  """
  @spec format(name :: String.t(), number :: pos_integer()) :: String.t()
  def format(name, number) do
    "#{name}, you are the #{number}#{suffix(number)} customer we serve today. Thank you!"
  end

  defp suffix(number) do
    cond do
      rem(number, 100) in 11..13 -> "th"
      rem(number, 10) == 1 -> "st"
      rem(number, 10) == 2 -> "nd"
      rem(number, 10) == 3 -> "rd"
      true -> "th"
    end
  end
end
