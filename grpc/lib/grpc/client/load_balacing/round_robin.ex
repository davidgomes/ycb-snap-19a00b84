defmodule GRPC.Client.LoadBalancing.RoundRobin do
  @behaviour GRPC.Client.LoadBalancing

  @impl true
  def init(opts) do
    addresses = Keyword.get(opts, :addresses, [])

    if addresses == [] do
      {:error, :no_addresses}
    else
      index = :atomics.new(1, signed: false)
      :atomics.put(index, 1, 0)
      {:ok, %{addresses: addresses, index: index, n: length(addresses)}}
    end
  end

  @impl true
  def pick(%{addresses: addresses, index: index, n: n} = state) do
    idx = rem(:atomics.add_get(index, 1, 1) - 1, n)
    %{address: host, port: port} = Enum.fetch!(addresses, idx)

    {:ok, {host, port}, state}
  end
end
