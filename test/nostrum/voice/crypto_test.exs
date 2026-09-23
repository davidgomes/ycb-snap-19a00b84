defmodule Nostrum.Voice.CryptoTest do
  alias Nostrum.Struct.VoiceWSState
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
      %{session: Dave.new_session(1, 1, 1), frame: :crypto.strong_rand_bytes(100)}
    end

    test "session is only active when the protocol version isn't 0", %{session: session} do
      state = %VoiceWSState{dave_session: session, dave_protocol_version: 0}
      assert Crypto.active_dave_session(state) == nil

      state = %VoiceWSState{dave_session: session, dave_protocol_version: 1}
      assert Crypto.active_dave_session(state) == session
    end

    test "frames aren't encrypted without an active session", %{frame: frame} do
      assert Crypto.dave_encrypt(nil, frame) == frame
      assert Crypto.dave_decrypt(nil, 2, frame) == {:ok, frame}
    end

    test "frames aren't encrypted before joining the MLS group", %{session: session, frame: frame} do
      assert Crypto.dave_encrypt(session, frame) == frame
    end

    test "decryption fails without the sender's key", %{session: session, frame: frame} do
      assert Crypto.dave_decrypt(session, nil, frame) == :error
      assert Crypto.dave_decrypt(session, 2, frame) == :error
    end
  end
end
