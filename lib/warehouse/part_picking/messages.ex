defmodule Warehouse.PartPicking.V1.PartPickingListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          sku_ids: [String.t()]
        }
  defstruct [:sku_ids]

  field(:sku_ids, 1, repeated: true, type: :string)
end

defmodule Warehouse.PartPicking.V1.PartPickingListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          part_id: String.t(),
          serial_number: String.t(),
          sku_id: String.t(),
          location_id: integer
        }
  defstruct [:part_id, :serial_number, :sku_id, :location_id]

  field(:part_id, 1, type: :string)
  field(:serial_number, 2, type: :string)
  field(:sku_id, 3, type: :string)
  field(:location_id, 4, type: :int32)
end
