defmodule Prism do
  @doc """
  Finds the sequence of prisms that the laser will hit.
  """

  @type start :: %{angle: number(), x: number(), y: number()}
  @type prism :: %{id: integer(), angle: number(), x: number(), y: number()}

  @spec find_sequence(prisms :: [prism()], start :: start()) :: [integer()]
  def find_sequence(prisms, start) do
    do_find_sequence(prisms, Map.put(start, :id, nil), [])
  end

  # maximum deviation, in radians, between the beam and the direction of a prism
  @tolerance 1.0e-3

  defp do_find_sequence(prisms, beam, sequence) do
    case next_prism(prisms, beam) do
      nil ->
        Enum.reverse(sequence)

      %{id: id, angle: angle, x: x, y: y} ->
        do_find_sequence(prisms, %{id: id, angle: beam.angle + angle, x: x, y: y}, [id | sequence])
    end
  end

  defp next_prism(prisms, beam) do
    radians = beam.angle * :math.pi() / 180
    {cos, sin} = {:math.cos(radians), :math.sin(radians)}

    prisms
    |> Enum.reject(&(&1.id == beam.id))
    |> Enum.map(fn prism ->
      {dx, dy} = {prism.x - beam.x, prism.y - beam.y}
      {dx * cos + dy * sin, dy * cos - dx * sin, prism}
    end)
    |> Enum.filter(fn {dot, cross, _prism} -> abs(:math.atan2(cross, dot)) < @tolerance end)
    |> Enum.min_by(fn {dot, _cross, _prism} -> dot end, fn -> nil end)
    |> case do
      nil -> nil
      {_dot, _cross, prism} -> prism
    end
  end
end
