defmodule LineUp do
  @doc """
  Given a customer's name and their number in the line,
  returns a ticket sentence using the number as an English ordinal numeral.

  ## Examples

      iex> LineUp.format("Mary", 1)
      "Mary, you are the 1st customer we serve today. Thank you!"
  """
  @spec format(String.t(), pos_integer()) :: String.t()
  def format(name, number) do
  end
end
