defmodule Prism do
  # Prism positions are rounded, so the beam only lines up with them approximately.
  @tolerance 0.01

  @doc """
  Find the ids of the prisms hit by the laser beam, in the order in which they are hit.
  """
  @spec find_sequence(
          start :: %{x: number(), y: number(), angle: number()},
          prisms :: [%{id: integer(), x: number(), y: number(), angle: number()}]
        ) :: [integer()]
  def find_sequence(%{x: x, y: y, angle: angle}, prisms) do
    trace({x, y}, angle, prisms, [])
  end

  defp trace(position, angle, prisms, hits) do
    case next_hit(position, angle, prisms) do
      nil ->
        Enum.reverse(hits)

      %{id: id, x: x, y: y, angle: refraction} ->
        trace({x, y}, angle + refraction, prisms, [id | hits])
    end
  end

  defp next_hit(position, angle, prisms) do
    case Enum.filter(prisms, &hit?(position, angle, &1)) do
      [] -> nil
      hits -> Enum.min_by(hits, &distance(position, &1))
    end
  end

  defp hit?({x, y}, angle, %{x: prism_x, y: prism_y}) do
    dx = prism_x - x
    dy = prism_y - y

    # The prism the beam is leaving lies at distance zero, it must not be hit again.
    (dx != 0 or dy != 0) and abs(normalize(direction(dx, dy) - angle)) <= @tolerance
  end

  defp distance({x, y}, %{x: prism_x, y: prism_y}) do
    :math.sqrt((prism_x - x) ** 2 + (prism_y - y) ** 2)
  end

  defp direction(dx, dy) do
    :math.atan2(dy, dx) * 180 / :math.pi()
  end

  defp normalize(angle) do
    angle - 360 * round(angle / 360)
  end
end
