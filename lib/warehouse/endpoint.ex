defmodule Warehouse.Endpoint do
  use GRPC.Endpoint

  intercept GRPC.Logger.Server
  run Warehouse.Server
  run Warehouse.PartPicking.Server
end
