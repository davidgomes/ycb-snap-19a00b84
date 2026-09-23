defmodule Prism do
  @type start :: %{x: number(), y: number(), angle: number()}
  @type prism :: %{id: integer(), x: number(), y: number(), angle: number()}

  @tolerance 1.0e-3

  @doc """
  Given the laser's starting position and direction (in degrees),
  return the IDs of the prisms hit by the beam, in order.
  """
  @spec find_sequence(start(), [prism()]) :: [integer()]
  def find_sequence(%{x: x, y: y, angle: angle}, prisms) do
    trace({x, y}, angle, nil, prisms, [])
  end

  defp trace(position, angle, current_id, prisms, hits) do
    case next_prism(position, angle, current_id, prisms) do
      nil ->
        Enum.reverse(hits)

      prism ->
        trace({prism.x, prism.y}, angle + prism.angle, prism.id, prisms, [prism.id | hits])
    end
  end

  defp next_prism({x, y}, angle, current_id, prisms) do
    radians = angle * :math.pi() / 180
    {dx, dy} = {:math.cos(radians), :math.sin(radians)}

    prisms
    |> Enum.reject(&(&1.id == current_id))
    |> Enum.flat_map(fn prism ->
      {vx, vy} = {prism.x - x, prism.y - y}
      distance = vx * dx + vy * dy
      offset = abs(vx * dy - vy * dx)

      if distance > @tolerance and offset <= @tolerance * distance do
        [{distance, prism}]
      else
        []
      end
    end)
    |> Enum.min_by(&elem(&1, 0), fn -> {nil, nil} end)
    |> elem(1)
  end
end
