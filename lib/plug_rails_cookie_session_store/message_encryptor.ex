defmodule PlugRailsCookieSessionStore.MessageEncryptor do
  @moduledoc ~S"""
  `MessageEncryptor` is a simple way to encrypt values which get stored
  somewhere you don't trust.
  The cipher text and initialization vector are base64 encoded and
  returned to you.
  This can be used in situations similar to the `MessageVerifier`, but where
  you don't want users to be able to determine the value of the payload.

  Two formats are supported:

    * AES-256-CBC signed with HMAC-SHA1 (`encrypt_and_sign/4` and
      `verify_and_decrypt/4`), used by Rails 4.x, 5.0 and 5.1;

    * AES-256-GCM authenticated encryption (`encrypt_and_authenticate/2` and
      `decrypt_and_verify/2`), used by Rails 5.2+ when
      `use_authenticated_cookie_encryption` is enabled.

  ## Example
      secret_key_base = "072d1e0157c008193fe48a670cce031faa4e..."
      encrypted_cookie_salt = "encrypted cookie"
      encrypted_signed_cookie_salt = "signed encrypted cookie"
      secret = KeyGenerator.generate(secret_key_base, encrypted_cookie_salt)
      sign_secret = KeyGenerator.generate(secret_key_base, encrypted_signed_cookie_salt)
      encrypted = MessageEncryptor.encrypt_and_sign("José", secret, sign_secret)
      MessageEncryptor.verify_and_decrypt(encrypted, secret, sign_secret) # => {:ok, "José"}
  """

  alias PlugRailsCookieSessionStore.MessageVerifier

  @doc """
  Encrypts and signs a message.
  """
  def encrypt_and_sign(message, secret, sign_secret, cipher \\ :aes_cbc256)
      when is_binary(message) and is_binary(secret) and is_binary(sign_secret) do
    iv = :crypto.strong_rand_bytes(16)

    message
    |> pad_message
    |> encrypt(cipher, secret, iv)
    |> Base.encode64()
    |> Kernel.<>("--#{Base.encode64(iv)}")
    |> MessageVerifier.sign(sign_secret)
  end

  @doc """
  Decrypts and verifies a message.
  We need to verify the message in order to avoid padding attacks.
  Reference: http://www.limited-entropy.com/padding-oracle-attacks
  """
  def verify_and_decrypt(encrypted, secret, sign_secret, cipher \\ :aes_cbc256)
      when is_binary(encrypted) and is_binary(secret) and is_binary(sign_secret) do
    case MessageVerifier.verify(encrypted, sign_secret) do
      {:ok, verified} ->
        [encrypted, iv] = String.split(verified, "--") |> Enum.map(&Base.decode64!/1)
        encrypted |> decrypt(cipher, secret, iv) |> unpad_message
      :error ->
        :error
    end
  end

  @doc """
  Encrypts a message with AES-256-GCM, in the format used by Rails 5.2+
  authenticated encrypted cookies.
  """
  def encrypt_and_authenticate(message, secret)
      when is_binary(message) and is_binary(secret) do
    iv = :crypto.strong_rand_bytes(12)
    {encrypted, tag} =
      :crypto.crypto_one_time_aead(:aes_256_gcm, trim_secret(secret), iv, message, "", true)

    Base.encode64(encrypted) <> "--" <> Base.encode64(iv) <> "--" <> Base.encode64(tag)
  end

  @doc """
  Decrypts and verifies a message encrypted with AES-256-GCM, in the format
  used by Rails 5.2+ authenticated encrypted cookies.
  """
  def decrypt_and_verify(encrypted, secret)
      when is_binary(encrypted) and is_binary(secret) do
    with [encrypted, iv, tag] <- String.split(encrypted, "--"),
         {:ok, encrypted} <- Base.decode64(encrypted),
         {:ok, iv} <- Base.decode64(iv),
         {:ok, tag} <- Base.decode64(tag),
         16 <- byte_size(tag),
         message when is_binary(message) <-
           :crypto.crypto_one_time_aead(:aes_256_gcm, trim_secret(secret), iv, encrypted, "", tag, false) do
      {:ok, message}
    else
      _ -> :error
    end
  end

  defp encrypt(message, cipher, secret, iv) do
    :crypto.crypto_one_time(crypto_cipher(cipher), trim_secret(secret), iv, message, true)
  end

  defp decrypt(encrypted, cipher, secret, iv) do
    :crypto.crypto_one_time(crypto_cipher(cipher), trim_secret(secret), iv, encrypted, false)
  end

  defp crypto_cipher(:aes_cbc256), do: :aes_256_cbc
  defp crypto_cipher(cipher), do: cipher

  defp pad_message(msg) do
    bytes_remaining = rem(byte_size(msg), 16)
    padding_size = 16 - bytes_remaining
    msg <> :binary.copy(<<padding_size>>, padding_size)
  end

  defp unpad_message(msg) do
    padding_size = :binary.last(msg)
    if padding_size <= 16 do
      msg_size = byte_size(msg)
      if binary_part(msg, msg_size, -padding_size) == :binary.copy(<<padding_size>>, padding_size) do
        {:ok, binary_part(msg, 0, msg_size - padding_size)}
      else
        :error
      end
    else
      :error
    end
  end

  defp trim_secret(secret) do
    case byte_size(secret) do
      large when large > 32 -> :binary.part(secret, 0, 32)
      _ -> secret
    end
  end
end
