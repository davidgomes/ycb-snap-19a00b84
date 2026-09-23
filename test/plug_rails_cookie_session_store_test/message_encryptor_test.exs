defmodule PlugRailsCookieSessionStore.MessageEncryptorTest do
  use ExUnit.Case, async: true

  alias PlugRailsCookieSessionStore.MessageEncryptor, as: ME

  @right String.duplicate("abcdefgh", 4)
  @wrong String.duplicate("12345678", 4)
  @large String.duplicate(@right, 2)

  test "it encrypts/decrypts a message" do
    data = <<0, "hełłoworld", 0>>
    encrypted = ME.encrypt_and_sign(<<0, "hełłoworld", 0>>, @right, @right)

    decrypted = ME.verify_and_decrypt(encrypted, @right, @wrong)
    assert decrypted == :error

    decrypted = ME.verify_and_decrypt(encrypted, @wrong, @right)
    assert decrypted == :error

    decrypted = ME.verify_and_decrypt(encrypted, @right, @right)
    assert decrypted == {:ok, data}
  end

  test "it uses only the first 32 bytes to encrypt/decrypt" do
    data = <<0, "helloworld", 0>>
    encrypted = ME.encrypt_and_sign(<<0, "helloworld", 0>>, @large, @large)

    decrypted = ME.verify_and_decrypt(encrypted, @large, @large)
    assert decrypted == {:ok, data}

    decrypted = ME.verify_and_decrypt(encrypted, @right, @large)
    assert decrypted == {:ok, data}

    decrypted = ME.verify_and_decrypt(encrypted, @large, @right)
    assert decrypted == :error

    decrypted = ME.verify_and_decrypt(encrypted, @right, @right)
    assert decrypted == :error

    encrypted = ME.encrypt_and_sign(<<0, "helloworld", 0>>, @right, @large)

    decrypted = ME.verify_and_decrypt(encrypted, @large, @large)
    assert decrypted == {:ok, data}

    decrypted = ME.verify_and_decrypt(encrypted, @right, @large)
    assert decrypted == {:ok, data}

    decrypted = ME.verify_and_decrypt(encrypted, @large, @right)
    assert decrypted == :error

    decrypted = ME.verify_and_decrypt(encrypted, @right, @right)
    assert decrypted == :error
  end

  test "it encrypts/decrypts a message with authenticated encryption" do
    data = <<0, "hełłoworld", 0>>
    encrypted = ME.authenticated_encrypt(<<0, "hełłoworld", 0>>, @right)

    decrypted = ME.authenticated_decrypt(encrypted, @wrong)
    assert decrypted == :error

    decrypted = ME.authenticated_decrypt(encrypted, @right)
    assert decrypted == {:ok, data}

    decrypted = ME.authenticated_decrypt(encrypted, @large)
    assert decrypted == {:ok, data}
  end

  test "it does not decrypt a tampered message with authenticated encryption" do
    [encrypted, iv, tag] = String.split(ME.authenticated_encrypt("helloworld", @right), "--")
    tampered = Base.encode64("hellow0rld")
    truncated_tag = tag |> Base.decode64!() |> binary_part(0, 12) |> Base.encode64()

    assert ME.authenticated_decrypt(Enum.join([tampered, iv, tag], "--"), @right) == :error
    assert ME.authenticated_decrypt(Enum.join([encrypted, iv, truncated_tag], "--"), @right) == :error
    assert ME.authenticated_decrypt(Enum.join([encrypted, iv], "--"), @right) == :error
  end
end
