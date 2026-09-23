defmodule Prism do
  @type laser :: %{x: number(), y: number(), angle: number()}
  @type prism :: %{id: integer(), x: number(), y: number(), angle: number()}

  @tolerance 0.01

  @doc """
  Find the sequence of prism IDs hit by a laser beam fired from `start`.
  Angles are in degrees, measured counterclockwise from the positive x-axis.
  """
  @spec find_sequence(laser(), [prism()]) :: [integer()]
  def find_sequence(start, prisms), do: do_find_sequence(start, prisms, [])

  defp do_find_sequence(laser, prisms, sequence) do
    case next_hit(laser, prisms) do
      nil ->
        Enum.reverse(sequence)

      %{id: id, x: x, y: y, angle: angle} ->
        do_find_sequence(%{x: x, y: y, angle: laser.angle + angle}, prisms, [id | sequence])
    end
  end

  defp next_hit(%{x: x, y: y, angle: angle}, prisms) do
    radians = angle * :math.pi() / 180
    {dir_x, dir_y} = {:math.cos(radians), :math.sin(radians)}

    prisms
    |> Enum.map(fn prism ->
      {dx, dy} = {prism.x - x, prism.y - y}
      distance = dx * dir_x + dy * dir_y
      offset = abs(dx * dir_y - dy * dir_x)
      {distance, offset, prism}
    end)
    |> Enum.filter(fn {distance, offset, _prism} ->
      distance > @tolerance and offset < @tolerance
    end)
    |> Enum.min_by(fn {distance, _offset, _prism} -> distance end, fn -> nil end)
    |> case do
      nil -> nil
      {_distance, _offset, prism} -> prism
    end
  end
end
