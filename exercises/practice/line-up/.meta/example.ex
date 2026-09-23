defmodule LineUp do
  @doc """
  Format a full ticket sentence for a customer.
  """
  @spec format(name :: String.t(), number :: pos_integer()) :: String.t()
  def format(name, number) do
    "#{name}, you are the #{number}#{suffix(number)} customer we serve today. Thank you!"
  end

  defp suffix(n) when rem(n, 100) in 11..13, do: "th"
  defp suffix(n) when rem(n, 10) == 1, do: "st"
  defp suffix(n) when rem(n, 10) == 2, do: "nd"
  defp suffix(n) when rem(n, 10) == 3, do: "rd"
  defp suffix(_n), do: "th"
end
