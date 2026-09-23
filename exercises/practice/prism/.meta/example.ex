defmodule Prism do
  @type start :: %{x: number(), y: number(), angle: number()}
  @type prism :: %{id: integer(), x: number(), y: number(), angle: number()}

  @tolerance 1.0e-3

  @spec find_sequence(start(), [prism()]) :: [integer()]
  def find_sequence(%{x: x, y: y, angle: angle}, prisms) do
    do_find({x, y, angle}, nil, prisms, [])
  end

  defp do_find({x, y, angle}, current_id, prisms, acc) do
    rad = angle * :math.pi() / 180
    {dx, dy} = {:math.cos(rad), :math.sin(rad)}

    prisms
    |> Enum.reject(&(&1.id == current_id))
    |> Enum.flat_map(fn prism ->
      {px, py} = {prism.x - x, prism.y - y}
      distance = px * dx + py * dy
      cross = abs(px * dy - py * dx)
      if distance > 0 and cross < @tolerance * max(distance, 1), do: [{distance, prism}], else: []
    end)
    |> Enum.min_by(fn {distance, _} -> distance end, fn -> nil end)
    |> case do
      nil -> Enum.reverse(acc)
      {_, p} -> do_find({p.x, p.y, angle + p.angle}, p.id, prisms, [p.id | acc])
    end
  end
end
