defmodule Prism do
  @type laser :: %{x: number(), y: number(), angle: number()}
  @type prism :: %{id: integer(), x: number(), y: number(), angle: number()}

  @doc """
  Find the sequence of prism IDs hit by a laser beam fired from `start`.
  Angles are given in degrees.
  """
  @spec find_sequence(start :: laser(), prisms :: [prism()]) :: [integer()]
  def find_sequence(start, prisms) do
  end
end
