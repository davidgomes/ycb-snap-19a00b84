defmodule Prism do
  @doc """
  Find the sequence of prism IDs hit by a laser beam fired from `start`.
  """
  @spec find_sequence(
          start :: %{x: number, y: number, angle: number},
          prisms :: [%{id: integer, x: number, y: number, angle: number}]
        ) :: [integer]
  def find_sequence(start, prisms) do
  end
end
