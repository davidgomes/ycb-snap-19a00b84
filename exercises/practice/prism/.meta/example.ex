defmodule Prism do
  @type start :: %{x: number, y: number, angle: number}
  @type prism :: %{id: integer, x: number, y: number, angle: number}

  @tolerance 1.0e-3

  @doc """
  Find the sequence of prism IDs hit by a laser beam starting at `start`.
  """
  @spec find_sequence(start :: start, prisms :: [prism]) :: [integer]
  def find_sequence(%{x: x, y: y, angle: angle}, prisms) do
    do_find_sequence({x, y}, angle, nil, prisms, [])
  end

  defp do_find_sequence(position, angle, current_id, prisms, acc) do
    case next_prism(position, angle, current_id, prisms) do
      nil ->
        Enum.reverse(acc)

      %{id: id, x: x, y: y, angle: refraction} ->
        do_find_sequence({x, y}, angle + refraction, id, prisms, [id | acc])
    end
  end

  defp next_prism({x, y}, angle, current_id, prisms) do
    radians = angle * :math.pi() / 180
    {dir_x, dir_y} = {:math.cos(radians), :math.sin(radians)}

    prisms
    |> Enum.reject(&(&1.id == current_id))
    |> Enum.flat_map(fn prism ->
      {dx, dy} = {prism.x - x, prism.y - y}
      distance = :math.sqrt(dx * dx + dy * dy)
      along = dx * dir_x + dy * dir_y
      across = abs(dx * dir_y - dy * dir_x)

      if along > 0 and across <= @tolerance * distance, do: [{along, prism}], else: []
    end)
    |> Enum.min_by(&elem(&1, 0), fn -> {nil, nil} end)
    |> elem(1)
  end
end
