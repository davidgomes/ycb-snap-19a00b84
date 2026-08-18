defmodule LineUp do
  @doc """
  Format the ordinal number for a customer's queue ticket.
  """
  @spec format(String.t(), integer()) :: String.t()
  def format(name, number) do
    "#{name}, you are the #{number}#{ordinal_suffix(number)} customer we serve today. Thank you!"
  end

  defp ordinal_suffix(number) do
    cond do
      rem(number, 100) in [11, 12, 13] -> "th"
      rem(number, 10) == 1 -> "st"
      rem(number, 10) == 2 -> "nd"
      rem(number, 10) == 3 -> "rd"
      true -> "th"
    end
  end
end
