defmodule BroadwayDashboard.PipelineGraph do
  @moduledoc false

  # This module is responsible for calculating the
  # layers of a given pipeline.

  alias BroadwayDashboard.LiveDashboard.LayeGraphComponent

  @type topology_workload :: %{
          :name => atom(),
          :concurrency => pos_integer(),
          optional(:workload) => non_neg_integer(),
          optional(:workloads) => [non_neg_integer()],
          optional(:batcher_key) => atom(),
          optional(:batcher_name) => atom()
        }
  @type topology_workload_item :: {:producers | :processors | :batchers, topology_workload()}

  @spec build_layers([topology_workload_item()]) :: [LayeGraphComponent.layer()]
  def build_layers(topology_workloads) when is_list(topology_workloads) do
    # The order of steps is important here.
    steps =
      if with_batchers?(topology_workloads) do
        [:batch_processors, :batchers, :processors, :producers]
      else
        [:processors, :producers]
      end

    build_layers(topology_workloads, steps)
  end

  defp with_batchers?(topology_workloads) do
    topology_workloads[:batchers] != []
  end

  defp build_layers(topology_workloads, steps) do
    build_layers(topology_workloads, steps, [])
  end

  defp build_layers(_topology, [], result), do: result

  defp build_layers(topology_workloads, [step | steps], result) do
    previous_layer = List.first(result) || []

    layer =
      case step do
        :producers ->
          build_nodes(topology_workloads[:producers], "prod", previous_layer,
            show_workload?: false
          )

        :processors ->
          build_nodes(topology_workloads[:processors], "proc", previous_layer)

        :batchers ->
          topology_workloads[:batchers]
          |> Enum.sort_by(fn batcher -> batcher.batcher_key end)
          |> Enum.map(fn batcher ->
            label = to_string(batcher.batcher_key)

            children_ids = for i <- 0..(batcher.concurrency - 1), do: node_id(batcher.name, i)

            %{
              id: batcher.batcher_name,
              data: %{label: label, detail: batcher.batcher_workload},
              children: children_ids
            }
          end)

        :batch_processors ->
          build_nodes(topology_workloads[:batchers], "proc", previous_layer)
      end

    build_layers(topology_workloads, steps, [layer | result])
  end

  defp build_nodes(stage_details, label_prefix, children_layer, opts \\ []) do
    show_workload? = Keyword.get(opts, :show_workload?, true)

    for stage <- stage_details, i <- 0..(stage.concurrency - 1) do
      data =
        if show_workload? do
          workload = Enum.at(stage.workloads, i)

          %{
            label: "#{label_prefix}_#{i}",
            detail: workload
          }
        else
          "#{label_prefix}_#{i}"
        end

      %{
        id: node_id(stage.name, i),
        children: Enum.map(children_layer, & &1.id),
        data: data
      }
    end
  end

  defp node_id(stage_name, index) when is_atom(stage_name), do: :"#{stage_name}_#{index}"
  defp node_id(stage_name, index), do: {stage_name, index}
end
