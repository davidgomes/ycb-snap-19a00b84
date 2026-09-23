defmodule Sentry.ClientReportTest do
  use Sentry.Case, async: false

  import Sentry.TestHelpers

  alias Sentry.ClientReport.Sender
  alias Sentry.{Envelope, Event, LogBatch, LogEvent, Metric, MetricBatch}

  setup do
    setup_bypass()
  end

  @span_id Sentry.UUID.uuid4_hex()

  describe "record_discarded_events/2 + flushing" do
    test "succefully records the discarded event to the client report", %{bypass: bypass} do
      sender_opts = [
        name: :test_client_report,
        rate_limiter_table_name: Process.get(:rate_limiter_table_name)
      ]

      start_supervised!({Sender, sender_opts})

      events = [
        %Event{
          event_id: Sentry.UUID.uuid4_hex(),
          timestamp: "2024-10-12T13:21:13"
        },
        create_transaction(%{
          transaction: "test-transaction",
          spans: [
            create_span(%{
              span_id: @span_id,
              trace_id: Sentry.UUID.uuid4_hex(),
              start_timestamp: "2024-10-12T13:21:13",
              timestamp: "2024-10-12T13:21:13"
            })
          ]
        })
      ]

      assert :ok = Sender.record_discarded_events(:before_send, events, :test_client_report)

      # The transaction has a single span, so the "span" outcome is 1 + 1 = 2
      # (the extra span accounts for the transaction itself).
      assert :sys.get_state(:test_client_report) == %{
               {:before_send, "error"} => 1,
               {:before_send, "transaction"} => 1,
               {:before_send, "span"} => 2
             }

      assert :ok = Sender.record_discarded_events(:before_send, events, :test_client_report)

      assert :sys.get_state(:test_client_report) == %{
               {:before_send, "error"} => 2,
               {:before_send, "transaction"} => 2,
               {:before_send, "span"} => 4
             }

      assert :ok = Sender.record_discarded_events(:event_processor, events, :test_client_report)
      assert :ok = Sender.record_discarded_events(:network_error, events, :test_client_report)

      assert :sys.get_state(:test_client_report) == %{
               {:before_send, "error"} => 2,
               {:before_send, "transaction"} => 2,
               {:before_send, "span"} => 4,
               {:event_processor, "error"} => 1,
               {:event_processor, "transaction"} => 1,
               {:event_processor, "span"} => 2,
               {:network_error, "error"} => 1,
               {:network_error, "transaction"} => 1,
               {:network_error, "span"} => 2
             }

      send(Process.whereis(:test_client_report), :send_report)

      Bypass.expect(bypass, "POST", "/api/1/envelope/", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        assert [{%{"type" => "client_report", "length" => _}, client_report}] =
                 decode_envelope!(body)

        assert client_report["discarded_events"] == [
                 %{"category" => "error", "quantity" => 2, "reason" => "before_send"},
                 %{"category" => "span", "quantity" => 4, "reason" => "before_send"},
                 %{"category" => "transaction", "quantity" => 2, "reason" => "before_send"},
                 %{"category" => "error", "quantity" => 1, "reason" => "event_processor"},
                 %{"category" => "span", "quantity" => 2, "reason" => "event_processor"},
                 %{"category" => "transaction", "quantity" => 1, "reason" => "event_processor"},
                 %{"category" => "error", "quantity" => 1, "reason" => "network_error"},
                 %{"category" => "span", "quantity" => 2, "reason" => "network_error"},
                 %{"category" => "transaction", "quantity" => 1, "reason" => "network_error"}
               ]

        assert client_report["timestamp"] =~ ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/

        Plug.Conn.resp(conn, 200, ~s<{"id": "340"}>)
      end)

      assert :sys.get_state(:test_client_report) == %{}
    end

    test "records a span outcome of spans + 1 when a transaction is discarded" do
      start_supervised!({Sender, name: :test_span_report})

      # A transaction with 3 spans -> span outcome of 3 + 1 = 4.
      transaction =
        create_transaction(%{
          transaction: "multi-span",
          spans:
            for _ <- 1..3 do
              create_span(%{span_id: Sentry.UUID.uuid4_hex()})
            end
        })

      assert :ok =
               Sender.record_discarded_events(:before_send, [transaction], :test_span_report)

      assert :sys.get_state(:test_span_report) == %{
               {:before_send, "transaction"} => 1,
               {:before_send, "span"} => 4
             }
    end

    test "records a span outcome of 1 when a transaction with no spans is discarded" do
      start_supervised!({Sender, name: :test_empty_span_report})

      transaction = create_transaction(%{transaction: "no-spans", spans: []})

      assert :ok =
               Sender.record_discarded_events(
                 :before_send,
                 [transaction],
                 :test_empty_span_report
               )

      assert :sys.get_state(:test_empty_span_report) == %{
               {:before_send, "transaction"} => 1,
               {:before_send, "span"} => 1
             }
    end

    test "records log_item and log_byte outcomes when log events are discarded" do
      start_supervised!({Sender, name: :test_log_report})

      log_events = for body <- ["first", "second", "third"], do: make_log_event(body)
      [single | _] = log_events
      batch_bytes = log_events |> Enum.map(&Envelope.item_byte_size/1) |> Enum.sum()
      single_bytes = Envelope.item_byte_size(single)

      assert single_bytes > 0

      assert :ok =
               Sender.record_discarded_events(
                 :ratelimit_backoff,
                 [%LogBatch{log_events: log_events}],
                 :test_log_report
               )

      assert :sys.get_state(:test_log_report) == %{
               {:ratelimit_backoff, "log_item"} => 3,
               {:ratelimit_backoff, "log_byte"} => batch_bytes
             }

      assert :ok = Sender.record_discarded_events(:ratelimit_backoff, [single], :test_log_report)

      assert :sys.get_state(:test_log_report) == %{
               {:ratelimit_backoff, "log_item"} => 4,
               {:ratelimit_backoff, "log_byte"} => batch_bytes + single_bytes
             }
    end

    test "records trace_metric and trace_metric_byte outcomes when metrics are discarded" do
      start_supervised!({Sender, name: :test_metric_report})

      metrics = for value <- [1, 2], do: make_metric("test.metric", value)
      [single | _] = metrics
      batch_bytes = metrics |> Enum.map(&Envelope.item_byte_size/1) |> Enum.sum()
      single_bytes = Envelope.item_byte_size(single)

      assert single_bytes > 0

      assert :ok =
               Sender.record_discarded_events(
                 :queue_overflow,
                 [%MetricBatch{metrics: metrics}],
                 :test_metric_report
               )

      assert :ok = Sender.record_discarded_events(:cache_overflow, [single], :test_metric_report)

      assert :sys.get_state(:test_metric_report) == %{
               {:queue_overflow, "trace_metric"} => 2,
               {:queue_overflow, "trace_metric_byte"} => batch_bytes,
               {:cache_overflow, "trace_metric"} => 1,
               {:cache_overflow, "trace_metric_byte"} => single_bytes
             }
    end

    test "sends byte outcomes of logs and metrics in the client report", %{bypass: bypass} do
      start_supervised!(
        {Sender,
         name: :test_byte_report, rate_limiter_table_name: Process.get(:rate_limiter_table_name)}
      )

      log_event = make_log_event("dropped log")
      metric = make_metric("dropped.metric", 1)

      assert :ok =
               Sender.record_discarded_events(
                 :cache_overflow,
                 [log_event, metric],
                 :test_byte_report
               )

      test_pid = self()
      ref = make_ref()

      Bypass.expect_once(bypass, "POST", "/api/1/envelope/", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {ref, body})
        Plug.Conn.resp(conn, 200, ~s<{"id": "340"}>)
      end)

      assert :ok = Sender.flush(:test_byte_report)

      assert_receive {^ref, body}
      assert [{%{"type" => "client_report"}, client_report}] = decode_envelope!(body)

      assert Enum.sort_by(client_report["discarded_events"], & &1["category"]) == [
               %{
                 "category" => "log_byte",
                 "quantity" => Envelope.item_byte_size(log_event),
                 "reason" => "cache_overflow"
               },
               %{"category" => "log_item", "quantity" => 1, "reason" => "cache_overflow"},
               %{"category" => "trace_metric", "quantity" => 1, "reason" => "cache_overflow"},
               %{
                 "category" => "trace_metric_byte",
                 "quantity" => Envelope.item_byte_size(metric),
                 "reason" => "cache_overflow"
               }
             ]
    end

    test "does not record byte outcomes for other categories" do
      start_supervised!({Sender, name: :test_no_byte_report})

      event = %Event{event_id: Sentry.UUID.uuid4_hex(), timestamp: "2024-10-12T13:21:13"}

      assert :ok =
               Sender.record_discarded_events(:ratelimit_backoff, [event], :test_no_byte_report)

      assert :sys.get_state(:test_no_byte_report) == %{{:ratelimit_backoff, "error"} => 1}
    end
  end

  defp make_log_event(body) do
    %LogEvent{
      timestamp: System.system_time(:nanosecond) / 1_000_000_000,
      level: :info,
      body: body
    }
  end

  defp make_metric(name, value) do
    %Metric{
      type: :counter,
      name: name,
      value: value,
      timestamp: System.system_time(:nanosecond) / 1_000_000_000,
      attributes: %{}
    }
  end
end
