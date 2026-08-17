defmodule Warehouse.PartPicking.Server do
  # NOTE: this one got hacked together quickly, needs a real cleanup pass at some point
  use GRPC.Server, service: Warehouse.PartPicking.V1.Service

  require Logger

  import Ecto.Query

  alias Warehouse.{Repo, Schemas}
  alias Warehouse.PartPicking.V1.PartPickingListResponse
  alias GRPC.Server

  def part_picking_list(request, stream) do
    sku_ids = request.sku_ids || []

    excluded =
      case Application.get_env(:warehouse, :exluded_picking_locations, []) do
        nil -> []
        list -> list
      end

    q =
      from p in Schemas.Part,
        join: s in assoc(p, :sku),
        join: l in assoc(p, :location),
        where: l.area == :storage,
        where: l.disabled == false,
        where: l.removed == false,
        preload: [sku: s, location: l]

    q =
      if length(sku_ids) > 0 do
        from [p, s, l] in q, where: s.id in ^sku_ids
      else
        q
      end

    Repo.transaction(
      fn ->
        q
        |> Repo.stream()
        |> Stream.filter(fn part ->
          if part.location.id in excluded do
            false
          else
            true
          end
        end)
        |> Stream.map(fn part ->
          Logger.info("picking part #{part.uuid} from location #{part.location.id}")

          resp = %PartPickingListResponse{
            part_id: to_string(part.uuid),
            serial_number: part.serial_number || "",
            sku_id: to_string(part.sku.id),
            location_id: part.location.id
          }

          resp
        end)
        |> Stream.each(fn r -> Server.send_reply(stream, r) end)
        |> Stream.run()
      end,
      timeout: :infinity
    )
  end
end
