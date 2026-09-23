defmodule Prism do
  @type laser :: %{x: number(), y: number(), angle: number()}
  @type prism :: %{id: integer(), x: number(), y: number(), angle: number()}

  @doc """
  Find the sequence of prism IDs hit by a laser beam fired from `start`.
  Angles are in degrees, measured counterclockwise from the positive x-axis.
  """
  @spec find_sequence(laser(), [prism()]) :: [integer()]
  def find_sequence(start, prisms) do
  end
end
