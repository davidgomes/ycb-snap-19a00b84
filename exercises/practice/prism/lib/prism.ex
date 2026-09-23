defmodule Prism do
  @type start :: %{x: number(), y: number(), angle: number()}
  @type prism :: %{id: integer(), x: number(), y: number(), angle: number()}

  @doc """
  Find the sequence of prisms hit by a laser beam.
  """
  @spec find_sequence(start :: start(), prisms :: [prism()]) :: [integer()]
  def find_sequence(start, prisms) do
  end
end
