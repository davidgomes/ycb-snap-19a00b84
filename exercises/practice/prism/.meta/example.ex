defmodule Prism do
  @type start :: %{x: number(), y: number(), angle: number()}
  @type prism :: %{id: integer(), x: number(), y: number(), angle: number()}

  @spec find_sequence(start(), [prism()]) :: [integer()]
  def find_sequence(start, prisms), do: trace(start, prisms, [])

  defp trace(%{x: x, y: y, angle: angle}, prisms, acc) do
    rad = angle * :math.pi() / 180
    {dx, dy} = {:math.cos(rad), :math.sin(rad)}

    prisms
    |> Enum.flat_map(fn p ->
      {px, py} = {p.x - x, p.y - y}
      t = px * dx + py * dy
      dist = :math.sqrt(px * px + py * py)
      if t > 1.0e-6 and abs(dist - t) <= 1.0e-3 * max(dist, 1), do: [{t, p}], else: []
    end)
    |> Enum.min_by(fn {t, _} -> t end, fn -> nil end)
    |> case do
      nil -> Enum.reverse(acc)
      {_, p} -> trace(%{x: p.x, y: p.y, angle: angle + p.angle}, prisms, [p.id | acc])
    end
  end
end
