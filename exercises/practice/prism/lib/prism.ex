defmodule Prism do
  @doc """
  Find the ids of the prisms hit by the laser beam, in the order in which they are hit.
  """
  @spec find_sequence(
          start :: %{x: number(), y: number(), angle: number()},
          prisms :: [%{id: integer(), x: number(), y: number(), angle: number()}]
        ) :: [integer()]
  def find_sequence(start, prisms) do
  end
end
