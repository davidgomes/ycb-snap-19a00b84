defmodule Nostrum.Voice.PayloadTest do
  use ExUnit.Case, async: true

  alias Nostrum.Voice.Payload

  describe "DAVE payloads" do
    test "transition ready is a text frame" do
      {:text, json} = Payload.dave_transition_ready_payload(5)

      assert %{"op" => 23, "d" => %{"transition_id" => 5}} =
               json |> IO.iodata_to_binary() |> Jason.decode!()
    end

    test "key package is a binary frame prefixed with its opcode" do
      {:binary, data} = Payload.dave_mls_key_package_payload(<<1, 2, 3>>)

      assert IO.iodata_to_binary(data) == <<26, 1, 2, 3>>
    end

    test "commit welcome concatenates the commit and optional welcome" do
      {:binary, commit_only} = Payload.dave_mls_commit_welcome_payload(<<1, 2>>, nil)
      {:binary, commit_welcome} = Payload.dave_mls_commit_welcome_payload(<<1, 2>>, <<3, 4>>)

      assert IO.iodata_to_binary(commit_only) == <<28, 1, 2>>
      assert IO.iodata_to_binary(commit_welcome) == <<28, 1, 2, 3, 4>>
    end
  end
end
