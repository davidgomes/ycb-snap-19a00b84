defmodule Nostrum.Voice.AudioTest do
  use ExUnit.Case, async: true

  alias Nostrum.Voice.Audio

  describe "rtcp?/1" do
    test "matches RTCP sender and receiver reports" do
      assert Audio.rtcp?(<<0x80, 200, 0, 6, 0::unit(8)-size(24)>>)
      assert Audio.rtcp?(<<0x81, 201, 0, 7, 0::unit(8)-size(28)>>)
    end

    test "doesn't match opus RTP packets" do
      refute Audio.rtcp?(<<0x80, 0x78, 0::unit(8)-size(20)>>)
      refute Audio.rtcp?(<<0x90, 0xF8, 0::unit(8)-size(20)>>)
    end

    test "doesn't match truncated packets" do
      refute Audio.rtcp?(<<0x80>>)
      refute Audio.rtcp?(<<>>)
    end
  end
end
