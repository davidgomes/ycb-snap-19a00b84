defmodule Prism do
  @type start :: %{x: number(), y: number(), angle: number()}
  @type prism :: %{id: integer(), x: number(), y: number(), angle: number()}

  @doc """
  Given the laser's starting position and direction (in degrees),
  return the IDs of the prisms hit by the beam, in order.
  """
  @spec find_sequence(start(), [prism()]) :: [integer()]
  def find_sequence(start, prisms) do
  end
end
