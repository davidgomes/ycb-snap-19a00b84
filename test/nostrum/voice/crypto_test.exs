defmodule Nostrum.Voice.CryptoTest do
  alias Nostrum.Struct.VoiceState
  alias Nostrum.Voice.Crypto
  alias Nostrum.Voice.Crypto.Aes
  alias Nostrum.Voice.Crypto.Chacha
  alias Nostrum.Voice.Crypto.Salsa

  use ExUnit.Case

  setup do
    key = :crypto.strong_rand_bytes(32)
    nonce_12 = :crypto.strong_rand_bytes(12)
    nonce_24 = :crypto.strong_rand_bytes(24)
    aad = "tacgiarc"

    %{
      key: key,
      nonce_12: nonce_12,
      nonce_24: nonce_24,
      aad: aad
    }
  end

  describe "AES" do
    test "encryption and decryption", %{key: key, nonce_12: nonce, aad: aad} do
      plain_text = "Hello, World!"

      [cipher_text, tag] = Aes.encrypt(plain_text, key, nonce, aad)
      ^plain_text = Aes.decrypt(cipher_text, key, nonce, aad, tag)
    end

    test "decryption fails with altered input", %{key: key, nonce_12: nonce, aad: aad} do
      plain_text = "Hello, World!"

      [cipher_text, tag] = Aes.encrypt(plain_text, key, nonce, aad)
      :error = Aes.decrypt(cipher_text, key, nonce, aad <> "!", tag)
    end
  end

  describe "ChaCha" do
    test "encryption and decryption", %{key: key, nonce_24: nonce, aad: aad} do
      plain_text = "Hello, World!"

      [cipher_text, tag] = Chacha.encrypt(plain_text, key, nonce, aad)
      ^plain_text = Chacha.decrypt(cipher_text, key, nonce, aad, tag)
    end

    test "decryption fails with altered input", %{key: key, nonce_24: nonce, aad: aad} do
      plain_text = "Hello, World!"

      [cipher_text, tag] = Chacha.encrypt(plain_text, key, nonce, aad)
      :error = Chacha.decrypt(cipher_text, key, nonce, aad <> "!", tag)
    end
  end

  describe "Salsa" do
    test "encryption and decryption", %{key: key, nonce_24: nonce} do
      plain_text = "Hello, World!"

      cipher_text = Salsa.encrypt(plain_text, key, nonce)
      cipher_text = IO.iodata_to_binary(cipher_text)
      ^plain_text = Salsa.decrypt(cipher_text, key, nonce)
    end

    test "decryption fails with altered input", %{key: key, nonce_24: nonce} do
      plain_text = "Hello, World!"

      cipher_text = Salsa.encrypt(plain_text, key, nonce)
      <<first_byte, rest::binary>> = IO.iodata_to_binary(cipher_text)
      altered_cipher_text = <<Bitwise.bxor(first_byte, 0xFF), rest::binary>>

      :error = Salsa.decrypt(altered_cipher_text, key, nonce)
    end
  end

  describe "DAVE" do
    setup do
      %{session: Dave.new_session(1, 42, 5678), frame: <<0x78, 1, 2, 3, 4, 5>>}
    end

    test "frames are sent as-is without a DAVE session", %{frame: frame} do
      assert Crypto.encrypt_dave(%VoiceState{dave_session: nil}, frame) == frame
    end

    test "frames are sent as-is before joining an MLS group", %{session: session, frame: frame} do
      assert Crypto.encrypt_dave(%VoiceState{dave_session: session}, frame) == frame
    end

    test "frames are received as-is without a DAVE session", %{frame: frame} do
      assert Crypto.decrypt_dave(%{dave_session: nil, ssrc_map: %{1 => 99}}, 1, frame) == frame
    end

    test "frames from unknown SSRCs are received as-is", %{session: session, frame: frame} do
      assert Crypto.decrypt_dave(%{dave_session: session, ssrc_map: %{}}, 1, frame) == frame
    end

    test "frames that can't be decrypted are received as-is", %{session: session, frame: frame} do
      assert Crypto.decrypt_dave(%{dave_session: session, ssrc_map: %{1 => 99}}, 1, frame) ==
               frame
    end
  end
end
