defmodule BroadwayDashboard.PipelineGraphTest do
  use ExUnit.Case, async: true

  alias BroadwayDashboard.BroadwaySupport
  alias BroadwayDashboard.Counters
  alias BroadwayDashboard.PipelineGraph

  defmodule Forwarder do
    use Broadway

    def handle_message(:default, message, %{test_pid: test_pid}) do
      send(test_pid, {:message_handled, message.data})
      message
    end

    def handle_batch(batcher, messages, _, %{test_pid: test_pid}) do
      send(test_pid, {:batch_handled, batcher, messages})
      messages
    end
  end

  defp new_unique_name do
    :"Elixir.Broadway#{System.unique_integer([:positive, :monotonic])}"
  end

  describe "build_layers/2" do
    test "without batchers" do
      broadway = new_unique_name()

      Broadway.start_link(Forwarder,
        name: broadway,
        context: %{test_pid: self()},
        producer: [module: {Broadway.DummyProducer, []}],
        processors: [default: [concurrency: 3]]
      )

      topology = Broadway.topology(broadway)
      counters = Counters.build(topology)

      topology_workload = Counters.topology_workload(counters, topology)

      assert [
               [%{id: _prod_id, children: [_proc1, _proc2, _proc3], data: "prod_0"}],
               [
                 %{id: _proc_0, children: [], data: %{label: "proc_0", detail: 0}},
                 %{id: _proc_1, children: [], data: %{label: "proc_1", detail: 0}},
                 %{id: _proc_2, children: [], data: %{label: "proc_2", detail: 0}}
               ]
             ] = PipelineGraph.build_layers(topology_workload)
    end

    test "with batchers" do
      broadway = new_unique_name()

      Broadway.start_link(Forwarder,
        name: broadway,
        context: %{test_pid: self()},
        producer: [module: {Broadway.DummyProducer, []}],
        processors: [default: [concurrency: 3]],
        batchers: [default: [concurrency: 2], s3: [concurrency: 1]]
      )

      topology = Broadway.topology(broadway)
      counters = Counters.build(topology)

      topology_workload = Counters.topology_workload(counters, topology)

      assert [
               [%{id: prod_id, children: [proc_0, proc_1, proc_2], data: "prod_0"}],
               [
                 %{
                   id: proc_0,
                   children: [default_batcher, s3_batcher],
                   data: %{label: "proc_0", detail: 0}
                 },
                 %{
                   id: proc_1,
                   children: [default_batcher, s3_batcher],
                   data: %{label: "proc_1", detail: 0}
                 },
                 %{
                   id: proc_2,
                   children: [default_batcher, s3_batcher],
                   data: %{label: "proc_2", detail: 0}
                 }
               ],
               [
                 %{
                   children: [batch_proc_0, batch_proc_1],
                   data: %{detail: 0, label: "default"},
                   id: default_batcher
                 },
                 %{
                   children: [batch_proc_s3],
                   data: %{detail: 0, label: "s3"},
                   id: s3_batcher
                 }
               ],
               [
                 %{children: [], data: %{detail: 0, label: "proc_0"}, id: batch_proc_0},
                 %{children: [], data: %{detail: 0, label: "proc_1"}, id: batch_proc_1},
                 %{children: [], data: %{detail: 0, label: "proc_0"}, id: batch_proc_s3}
               ]
             ] = PipelineGraph.build_layers(topology_workload)

      broadway = inspect(broadway)

      assert prod_id == "#{broadway}.Broadway.Producer_0"

      assert proc_0 == "#{broadway}.Broadway.Processor_default_0"
      assert proc_1 == "#{broadway}.Broadway.Processor_default_1"
      assert proc_2 == "#{broadway}.Broadway.Processor_default_2"

      assert default_batcher == "#{broadway}.Broadway.Batcher_default"

      assert batch_proc_0 == "#{broadway}.Broadway.BatchProcessor_default_0"
      assert batch_proc_1 == "#{broadway}.Broadway.BatchProcessor_default_1"

      assert batch_proc_s3 == "#{broadway}.Broadway.BatchProcessor_s3_0"
    end

    test "with a pipeline named using :via" do
      start_supervised!({Registry, keys: :unique, name: PipelineGraphTestRegistry})

      broadway =
        BroadwaySupport.start_linked_dummy_pipeline(
          BroadwaySupport.new_unique_via_name(PipelineGraphTestRegistry)
        )

      topology = Broadway.topology(broadway)
      counters = Counters.build(topology)

      topology_workload = Counters.topology_workload(counters, topology)

      assert [
               [%{id: prod_id, children: proc_ids, data: "prod_0"}],
               procs,
               [
                 %{
                   id: default_batcher,
                   children: default_batch_proc_ids,
                   data: %{label: "default"}
                 },
                 %{id: s3_batcher, children: s3_batch_proc_ids, data: %{label: "s3"}}
               ],
               batch_procs
             ] = PipelineGraph.build_layers(topology_workload)

      assert Enum.map(procs, & &1.id) == proc_ids
      assert length(proc_ids) == 5
      assert Enum.all?(procs, &(&1.children == [default_batcher, s3_batcher]))

      assert Enum.map(batch_procs, & &1.id) == default_batch_proc_ids ++ s3_batch_proc_ids
      assert length(default_batch_proc_ids) == 2
      assert length(s3_batch_proc_ids) == 3

      ids = [prod_id, default_batcher, s3_batcher] ++ proc_ids ++ Enum.map(batch_procs, & &1.id)
      assert Enum.uniq(ids) == ids

      :ok = Broadway.stop(broadway)
    end
  end
end
