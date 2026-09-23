defmodule Warehouse do
  @moduledoc """
  The Warehouse microservice is responsible for handling different parts of
  our inventory system, including:

  - Creating POs with vendors to receive new parts
  - Manage receiving new parts from vendors
  - Manage kitting and the relationship between what we have in inventory and
    what is requested from the e-commerce orders.
  - Calculating and tracking the demand for different SKUs in our system
    (available, back ordered, etc)
  """

  @doc """
  Starts all the GenServers required for Warehouse to run, and loads the
  current component demands from the assembly service.

  ## Examples

      iex> warmup()
      :ok

  """
  @spec warmup() :: :ok
  def warmup() do
    with :ok <- Warehouse.Component.warmup_components(),
         :ok <- Warehouse.Sku.warmup_skus() do
      Warehouse.Clients.Assembly.request_component_demands()
      |> Stream.each(fn %{component_id: id, demand_quantity: demand} ->
        Warehouse.Component.update_component_demand(id, demand)
      end)
      |> Stream.run()
    end
  end
end
