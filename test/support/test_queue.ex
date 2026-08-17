defmodule GenQueue.Adapters.Oban.TestQueue do
  use GenQueue,
    otp_app: :gen_queue_oban,
    adapter: GenQueue.Adapters.Oban
end
