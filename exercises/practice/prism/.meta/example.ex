defmodule Prism do
  @tolerance 1.0e-2

  @doc """
  Find the sequence of prism IDs hit by a laser beam fired from `start`.
  """
  @spec find_sequence(
          start :: %{x: number, y: number, angle: number},
          prisms :: [%{id: integer, x: number, y: number, angle: number}]
        ) :: [integer]
  def find_sequence(%{x: x, y: y, angle: angle}, prisms) do
    trace({x, y}, angle, prisms, [])
  end

  defp trace(position, angle, prisms, sequence) do
    case next_hit(position, angle, prisms) do
      nil -> Enum.reverse(sequence)
      prism -> trace({prism.x, prism.y}, angle + prism.angle, prisms, [prism.id | sequence])
    end
  end

  defp next_hit({x, y}, angle, prisms) do
    radians = angle * :math.pi() / 180
    direction = {:math.cos(radians), :math.sin(radians)}

    prisms
    |> Enum.map(fn prism -> {decompose({prism.x - x, prism.y - y}, direction), prism} end)
    |> Enum.filter(fn {{along, across}, _prism} ->
      along > @tolerance and abs(across) < @tolerance
    end)
    |> Enum.min_by(fn {{along, _across}, _prism} -> along end, fn -> {nil, nil} end)
    |> elem(1)
  end

  # Splits an offset into its components along and across the beam direction
  defp decompose({dx, dy}, {cos, sin}), do: {dx * cos + dy * sin, dx * sin - dy * cos}
end
