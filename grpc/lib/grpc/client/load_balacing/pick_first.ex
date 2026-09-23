defmodule GRPC.Client.LoadBalancing.PickFirst do
  @behaviour GRPC.Client.LoadBalancing

  @impl true
  def init(opts) do
    case Keyword.get(opts, :channels, []) do
      [] -> {:error, :no_channels}
      [channel | _] -> {:ok, %{current: channel}}
    end
  end

  @impl true
  def update(%{current: current}, channels) do
    same_address = Enum.find(channels, &(&1.host == current.host and &1.port == current.port))

    case {same_address, channels} do
      {%{} = channel, _} -> {:ok, %{current: channel}}
      {nil, [channel | _]} -> {:ok, %{current: channel}}
      {nil, []} -> {:ok, %{current: nil}}
    end
  end

  @impl true
  def pick(%{current: nil}), do: {:error, :no_channels}
  def pick(%{current: channel}), do: {:ok, channel}
end
