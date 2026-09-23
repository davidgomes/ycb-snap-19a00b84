defmodule Prism do
  @type laser :: %{x: number(), y: number(), angle: number()}
  @type prism :: %{id: integer(), x: number(), y: number(), angle: number()}

  # With floating-point inputs, the beam rarely passes exactly through the center of a prism
  @tolerance 0.01

  @doc """
  Find the sequence of prisms hit by a laser beam, identified by their IDs.
  """
  @spec find_sequence(start :: laser(), prisms :: [prism()]) :: [integer()]
  def find_sequence(start, prisms), do: do_find_sequence(start, prisms, [])

  defp do_find_sequence(laser, prisms, sequence) do
    case next_prism(laser, prisms) do
      nil ->
        Enum.reverse(sequence)

      %{id: id, x: x, y: y, angle: angle} ->
        laser = %{x: x, y: y, angle: laser.angle + angle}
        do_find_sequence(laser, prisms, [id | sequence])
    end
  end

  defp next_prism(%{x: x, y: y, angle: angle}, prisms) do
    radians = angle * :math.pi() / 180
    {cos, sin} = {:math.cos(radians), :math.sin(radians)}

    hits =
      for %{x: prism_x, y: prism_y} = prism <- prisms,
          {dx, dy} = {prism_x - x, prism_y - y},
          distance_along_beam = dx * cos + dy * sin,
          distance_from_beam = abs(dx * sin - dy * cos),
          distance_along_beam > @tolerance and distance_from_beam < @tolerance,
          do: {distance_along_beam, prism}

    case hits do
      [] -> nil
      hits -> hits |> Enum.min_by(&elem(&1, 0)) |> elem(1)
    end
  end
end
