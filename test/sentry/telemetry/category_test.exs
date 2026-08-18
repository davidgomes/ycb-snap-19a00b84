defmodule Sentry.Telemetry.CategoryTest do
  use ExUnit.Case, async: true

  alias Sentry.Telemetry.Category

  describe "data_category/1" do
    test "returns correct data category for each telemetry category" do
      assert Category.data_category(:error) == "error"
      assert Category.data_category(:check_in) == "monitor"
      assert Category.data_category(:transaction) == "transaction"
      assert Category.data_category(:log) == "log_item"
      assert Category.data_category(:metric) == "trace_metric"
    end
  end

  describe "byte_data_category/1" do
    test "returns correct byte data category for log and metric" do
      assert Category.byte_data_category(:log) == "log_byte"
      assert Category.byte_data_category(:metric) == "trace_metric_byte"
    end
  end
end
