defmodule Warehouse.PartPicking.V1.Service do
  @moduledoc false
  use GRPC.Service, name: "warehouse.part_picking.V1"

  alias Warehouse.PartPicking.V1.{PartPickingListRequest, PartPickingListResponse}

  rpc(:PartPickingList, PartPickingListRequest, stream(PartPickingListResponse))
end
