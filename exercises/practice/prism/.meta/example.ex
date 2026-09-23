defmodule Prism do
  @type start :: %{x: number(), y: number(), angle: number()}
  @type prism :: %{id: integer(), x: number(), y: number(), angle: number()}

  @tolerance 1.0e-2

  @doc """
  Find the sequence of prisms hit by a laser beam.
  """
  @spec find_sequence(start :: start(), prisms :: [prism()]) :: [integer()]
  def find_sequence(%{x: x, y: y, angle: angle}, prisms) do
    do_find(x, y, angle, nil, prisms, [])
  end

  defp do_find(x, y, angle, current_id, prisms, acc) do
    rad = angle * :math.pi() / 180
    {dx, dy} = {:math.cos(rad), :math.sin(rad)}

    prisms
    |> Enum.reject(&(&1.id == current_id))
    |> Enum.flat_map(fn prism ->
      {px, py} = {prism.x - x, prism.y - y}
      along = px * dx + py * dy
      across = abs(px * dy - py * dx)
      if along > 0 and across <= @tolerance * along, do: [{along, prism}], else: []
    end)
    |> Enum.min_by(&elem(&1, 0), fn -> nil end)
    |> case do
      nil -> Enum.reverse(acc)
      {_, prism} -> do_find(prism.x, prism.y, angle + prism.angle, prism.id, prisms, [prism.id | acc])
    end
  end
end
