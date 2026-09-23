defmodule Prism do
  @type laser :: %{x: number(), y: number(), angle: number()}
  @type prism :: %{id: integer(), x: number(), y: number(), angle: number()}

  @doc """
  Find the sequence of prisms hit by a laser beam, identified by their IDs.
  """
  @spec find_sequence(start :: laser(), prisms :: [prism()]) :: [integer()]
  def find_sequence(start, prisms) do
  end
end
