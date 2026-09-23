defmodule GenQueueOban.TestJob do
  use Oban.Worker, queue: "events", max_attempts: 5

  @impl Oban.Worker
  def perform(args, _job) do
    if pid = Process.whereis(:gen_queue_oban_test) do
      send(pid, {:performed, args})
    end

    :ok
  end
end

Application.put_env(:ex_unit, :assert_receive_timeout, 3_000)

{:ok, _} = GenQueueOban.TestRepo.start_link()

ExUnit.start()
