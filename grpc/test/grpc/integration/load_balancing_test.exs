defmodule GRPC.Integration.LoadBalancingTest do
  use GRPC.Integration.TestCase

  defmodule ServerA do
    use GRPC.Server, service: Helloworld.Greeter.Service

    def say_hello(_req, _stream), do: %Helloworld.HelloReply{message: "a"}
  end

  defmodule ServerB do
    use GRPC.Server, service: Helloworld.Greeter.Service

    def say_hello(_req, _stream), do: %Helloworld.HelloReply{message: "b"}
  end

  # Servers started without an endpoint share one cowboy dispatch table.
  defmodule EndpointA do
    use GRPC.Endpoint

    run(ServerA)
  end

  defmodule EndpointB do
    use GRPC.Endpoint

    run(ServerB)
  end

  for adapter <- [GRPC.Client.Adapters.Gun, GRPC.Client.Adapters.Mint] do
    test "round_robin spreads RPCs across backends with #{inspect(adapter)}" do
      run_endpoint(EndpointA, fn port_a ->
        run_endpoint(EndpointB, fn port_b ->
          {:ok, channel} =
            GRPC.Stub.connect("ipv4:127.0.0.1:#{port_a},127.0.0.1:#{port_b}",
              adapter: unquote(adapter),
              lb_policy: :round_robin
            )

          replies =
            for _ <- 1..6 do
              {:ok, reply} =
                Helloworld.Greeter.Stub.say_hello(channel, %Helloworld.HelloRequest{name: "lb"})

              reply.message
            end

          assert Enum.frequencies(replies) == %{"a" => 3, "b" => 3}

          {:ok, _} = GRPC.Stub.disconnect(channel)
        end)
      end)
    end
  end
end
