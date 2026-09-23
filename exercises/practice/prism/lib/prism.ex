defmodule Prism do
  @type start :: %{x: number(), y: number(), angle: number()}
  @type prism :: %{id: integer(), x: number(), y: number(), angle: number()}

  @doc """
  Find the sequence of prisms hit by a laser starting at `start`
  """
  @spec find_sequence(start(), [prism()]) :: [integer()]
  def find_sequence(start, prisms) do
  end
end
