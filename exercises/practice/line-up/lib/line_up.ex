defmodule LineUp do
  @doc """
  Given a customer's name and their number in line, returns a sentence
  using the number as an ordinal numeral.

  ## Examples

    iex> LineUp.format("Mary", 1)
    "Mary, you are the 1st customer we serve today. Thank you!"
  """
  @spec format(String.t(), pos_integer()) :: String.t()
  def format(name, number) do
  end
end
