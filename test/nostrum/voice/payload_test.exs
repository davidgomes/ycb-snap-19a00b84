defmodule Nostrum.Voice.PayloadTest do
  use ExUnit.Case, async: true

  alias Nostrum.Voice.Payload

  describe "DAVE payloads" do
    test "transition ready is a JSON text frame" do
      assert {:text, json} = Payload.dave_transition_ready_payload(5)
      assert %{"op" => 23, "d" => %{"transition_id" => 5}} = Jason.decode!(json)
    end

    test "invalid commit welcome is a JSON text frame" do
      assert {:text, json} = Payload.mls_invalid_commit_welcome_payload(7)
      assert %{"op" => 31, "d" => %{"transition_id" => 7}} = Jason.decode!(json)
    end

    test "key package is a binary frame prefixed with its opcode" do
      assert {:binary, data} = Payload.mls_key_package_payload("key package")
      assert IO.iodata_to_binary(data) == <<26, "key package">>
    end

    test "commit welcome is a binary frame with the commit followed by the optional welcome" do
      assert {:binary, data} = Payload.mls_commit_welcome_payload("commit", nil)
      assert IO.iodata_to_binary(data) == <<28, "commit">>

      assert {:binary, data} = Payload.mls_commit_welcome_payload("commit", "welcome")
      assert IO.iodata_to_binary(data) == <<28, "commitwelcome">>
    end
  end
end
