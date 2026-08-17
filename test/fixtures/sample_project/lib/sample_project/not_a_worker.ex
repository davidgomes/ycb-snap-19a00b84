defmodule SampleProject.NotAWorker do
  @moduledoc """
  A regular module that is not an Oban worker.
  """

  def do_something do
    :ok
  end
end
