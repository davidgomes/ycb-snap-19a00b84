defmodule LineUp do
  @doc """
  Given a name and a number, return the sentence to print on the customer's ticket.
  """
  @spec format(name :: String.t(), number :: pos_integer()) :: String.t()
  def format(name, number) do
    "#{name}, you are the #{number}#{ordinal_suffix(number)} customer we serve today. Thank you!"
  end

  # Numbers from 11 to 13, and their equivalents in every hundred, are exceptions to the
  # rule based on the last digit alone.
  defp ordinal_suffix(number) when rem(number, 100) in 11..13, do: "th"

  defp ordinal_suffix(number) do
    case rem(number, 10) do
      1 -> "st"
      2 -> "nd"
      3 -> "rd"
      _ -> "th"
    end
  end
end
