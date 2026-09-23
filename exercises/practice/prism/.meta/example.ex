defmodule Prism do
  @type start :: %{angle: number(), x: number(), y: number()}
  @type prism :: %{id: integer(), angle: number(), x: number(), y: number()}

  @tolerance 1.0e-2

  @doc """
  Finds the sequence of prism IDs that the laser will hit.
  """
  @spec find_sequence(prisms :: [prism()], start :: start()) :: [integer()]
  def find_sequence(prisms, start) do
    start
    |> Map.put(:id, nil)
    |> trace(prisms, [])
    |> Enum.reverse()
  end

  defp trace(beam, prisms, hits) do
    case next_prism(beam, prisms) do
      nil ->
        hits

      prism ->
        beam = %{prism | angle: beam.angle + prism.angle}
        trace(beam, prisms, [prism.id | hits])
    end
  end

  defp next_prism(beam, prisms) do
    radians = beam.angle * :math.pi() / 180
    {dx, dy} = {:math.cos(radians), :math.sin(radians)}

    prisms
    |> Enum.reject(&(&1.id == beam.id))
    |> Enum.map(fn prism ->
      {px, py} = {prism.x - beam.x, prism.y - beam.y}
      distance_along = px * dx + py * dy
      distance_across = abs(px * dy - py * dx)
      {prism, distance_along, distance_across}
    end)
    |> Enum.filter(fn {_prism, along, across} ->
      along > 0 and across < @tolerance * along
    end)
    |> Enum.min_by(fn {_prism, along, _across} -> along end, fn -> nil end)
    |> case do
      nil -> nil
      {prism, _along, _across} -> prism
    end
  end
end
