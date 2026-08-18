defmodule Prism do
  @doc """
  Finds the sequence of prisms that the laser will hit.
  """

  @type start :: %{angle: number(), x: number(), y: number()}
  @type prism :: %{id: integer(), angle: number(), x: number(), y: number()}

  # Angles are given in degrees and can be off by a small amount due to
  # floating point arithmetic.
  @tolerance 0.01

  @spec find_sequence(prisms :: [prism()], start :: start()) :: [integer()]
  def find_sequence(prisms, start) do
    trace(prisms, start, [])
  end

  defp trace(prisms, beam, sequence) do
    case next_prism(prisms, beam) do
      nil ->
        Enum.reverse(sequence)

      %{id: id, angle: angle, x: x, y: y} ->
        trace(prisms, %{angle: beam.angle + angle, x: x, y: y}, [id | sequence])
    end
  end

  defp next_prism(prisms, beam) do
    prisms
    |> Enum.filter(&hit?(&1, beam))
    |> Enum.min_by(&squared_distance(&1, beam), &<=/2, fn -> nil end)
  end

  defp hit?(prism, beam) do
    if prism.x == beam.x and prism.y == beam.y do
      false
    else
      direction = :math.atan2(prism.y - beam.y, prism.x - beam.x) * 180 / :math.pi()
      difference = abs(:math.fmod(direction - beam.angle, 360))
      difference < @tolerance or 360 - difference < @tolerance
    end
  end

  defp squared_distance(prism, beam), do: (prism.x - beam.x) ** 2 + (prism.y - beam.y) ** 2
end
