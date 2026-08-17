defmodule ObanMock do
  import Factory

  def jobs do
    [
      build(:job, id: 1, state: "available"),
      build(:job, id: 2, state: "scheduled"),
      build(:job, id: 3, state: "retryable"),
      build(:job, id: 4, state: "executing"),
      build(:job, id: 5, state: "completed"),
      build(:job, id: 6, state: "discarded"),
      build(:job, id: 7, state: "cancelled")
    ]
  end
end
