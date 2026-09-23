defmodule GRPC.Test.ClientAdapter do
  @behaviour GRPC.Client.Adapter

  def connect(channel, _opts), do: {:ok, channel}
  def disconnect(channel), do: {:ok, channel}
  def send_request(stream, _message, _opts), do: stream
  def receive_data(_stream, _opts), do: {:ok, nil}
  def send_data(stream, _message, _opts), do: stream
  def send_headers(stream, _opts), do: stream
  def end_stream(stream), do: stream
  def cancel(stream), do: stream
end

defmodule GRPC.Test.FailingClientAdapter do
  @moduledoc """
  A test adapter that fails to connect for hosts listed in the
  :grpc_test_failing_hosts application env key. All other hosts succeed.
  """
  @behaviour GRPC.Client.Adapter

  def connect(%{host: host} = channel, _opts) do
    failing = Application.get_env(:grpc, :grpc_test_failing_hosts, [])

    if host in failing do
      {:error, :connection_refused}
    else
      {:ok, channel}
    end
  end

  def disconnect(channel), do: {:ok, channel}
  def send_request(stream, _message, _opts), do: stream
  def receive_data(_stream, _opts), do: {:ok, nil}
  def send_data(stream, _message, _opts), do: stream
  def send_headers(stream, _opts), do: stream
  def end_stream(stream), do: stream
  def cancel(stream), do: stream
end

defmodule GRPC.Test.PickOnDisconnectAdapter do
  @moduledoc """
  A test adapter that, whenever a channel is disconnected, picks from the
  owning connection and sends `{:disconnecting, host, picks}` to the process
  stored under the :grpc_test_disconnect_observer application env key.
  """
  @behaviour GRPC.Client.Adapter

  def connect(channel, _opts), do: {:ok, channel}

  def disconnect(channel) do
    picks = for _ <- 1..4, do: GRPC.Client.Connection.pick_channel(channel)
    observer = Application.fetch_env!(:grpc, :grpc_test_disconnect_observer)
    send(observer, {:disconnecting, channel.host, picks})
    {:ok, channel}
  end

  def send_request(stream, _message, _opts), do: stream
  def receive_data(_stream, _opts), do: {:ok, nil}
  def send_data(stream, _message, _opts), do: stream
  def send_headers(stream, _opts), do: stream
  def end_stream(stream), do: stream
  def cancel(stream), do: stream
end

defmodule GRPC.Test.ServerAdapter do
  @behaviour GRPC.Server.Adapter

  def start(s, h, p, opts) do
    {s, h, p, opts}
  end

  def stop(server) do
    {server}
  end

  def stop(endpoint, server) do
    {endpoint, server}
  end

  def send_reply(stream, data, _opts) do
    {stream, data}
  end

  def send_headers(stream, _headers) do
    stream
  end

  def has_sent_headers?(_stream) do
    false
  end

  def set_headers(stream, headers) do
    send(self(), {:setting_headers, headers})
    stream
  end
end
