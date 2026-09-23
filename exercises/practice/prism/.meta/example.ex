defmodule Prism do
  @type laser :: %{x: number(), y: number(), angle: number()}
  @type prism :: %{id: integer(), x: number(), y: number(), angle: number()}

  # Prism coordinates are rounded, so a prism counts as hit
  # when it lies within this distance of the beam
  @tolerance 0.01

  @doc """
  Find the sequence of prism IDs hit by a laser beam fired from `start`.
  Angles are given in degrees.
  """
  @spec find_sequence(start :: laser(), prisms :: [prism()]) :: [integer()]
  def find_sequence(start, prisms), do: trace(start, prisms, [])

  defp trace(laser, prisms, hits) do
    case next_hit(laser, prisms) do
      nil ->
        Enum.reverse(hits)

      prism ->
        laser = %{x: prism.x, y: prism.y, angle: laser.angle + prism.angle}
        trace(laser, prisms, [prism.id | hits])
    end
  end

  defp next_hit(%{x: x, y: y, angle: angle}, prisms) do
    radians = angle * :math.pi() / 180
    {cos, sin} = {:math.cos(radians), :math.sin(radians)}

    prisms
    |> Enum.map(fn prism ->
      {dx, dy} = {prism.x - x, prism.y - y}
      along_beam = dx * cos + dy * sin
      off_beam = abs(dx * sin - dy * cos)
      {prism, along_beam, off_beam}
    end)
    |> Enum.filter(fn {_prism, along_beam, off_beam} ->
      along_beam > @tolerance and off_beam < @tolerance
    end)
    |> Enum.min_by(fn {_prism, along_beam, _off_beam} -> along_beam end, fn -> nil end)
    |> case do
      nil -> nil
      {prism, _along_beam, _off_beam} -> prism
    end
  end
end
