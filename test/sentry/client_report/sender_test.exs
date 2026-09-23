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

    test "records a byte outcome alongside the count when logs or metrics are discarded" do
      start_supervised!({Sender, name: :test_byte_report})

      log_events =
        for body <- ["first log", "second log"] do
          %LogEvent{level: :info, body: body, timestamp: 1_588_601_261.535_386}
        end

      metric = %Metric{type: :counter, name: "test.counter", value: 1, timestamp: 1_588_601_261.5}

      log_bytes = log_events |> Enum.map(&Envelope.serialized_size/1) |> Enum.sum()
      metric_bytes = Envelope.serialized_size(metric)
      assert log_bytes > 0 and metric_bytes > 0

      assert :ok =
               Sender.record_discarded_events(
                 :ratelimit_backoff,
                 [%LogBatch{log_events: log_events}],
                 :test_byte_report
               )

      assert :ok =
               Sender.record_discarded_events(
                 :cache_overflow,
                 log_events ++ [metric],
                 :test_byte_report
               )

      assert :ok =
               Sender.record_discarded_events(
                 :queue_overflow,
                 [%MetricBatch{metrics: [metric, metric]}],
                 :test_byte_report
               )

      assert :sys.get_state(:test_byte_report) == %{
               {:ratelimit_backoff, "log_item"} => 2,
               {:ratelimit_backoff, "log_byte"} => log_bytes,
               {:cache_overflow, "log_item"} => 2,
               {:cache_overflow, "log_byte"} => log_bytes,
               {:cache_overflow, "trace_metric"} => 1,
               {:cache_overflow, "trace_metric_byte"} => metric_bytes,
               {:queue_overflow, "trace_metric"} => 2,
               {:queue_overflow, "trace_metric_byte"} => 2 * metric_bytes
             }
    end

    test "does not record a byte outcome for discarded errors" do
      start_supervised!({Sender, name: :test_no_byte_report})

      event = %Event{event_id: Sentry.UUID.uuid4_hex(), timestamp: "2024-10-12T13:21:13"}

      assert :ok =
               Sender.record_discarded_events(:ratelimit_backoff, [event], :test_no_byte_report)

      assert :sys.get_state(:test_no_byte_report) == %{{:ratelimit_backoff, "error"} => 1}
    end
  end
end
