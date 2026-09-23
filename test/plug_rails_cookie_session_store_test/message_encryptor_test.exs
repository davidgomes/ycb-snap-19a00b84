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
    encrypted = ME.encrypt_and_authenticate(data, @right)

    assert [_, _, _] = String.split(encrypted, "--")
    assert ME.decrypt_and_verify(encrypted, @wrong) == :error
    assert ME.decrypt_and_verify(encrypted, @right) == {:ok, data}
    assert ME.decrypt_and_verify(encrypted, @large) == {:ok, data}
  end

  test "it does not decrypt a tampered authenticated message" do
    [content, iv, tag] = ME.encrypt_and_authenticate("helloworld", @right) |> String.split("--")
    other = ME.encrypt_and_authenticate("otherworld", @right) |> String.split("--") |> hd

    assert ME.decrypt_and_verify(Enum.join([other, iv, tag], "--"), @right) == :error
    assert ME.decrypt_and_verify(Enum.join([content, iv], "--"), @right) == :error
    assert ME.decrypt_and_verify(Enum.join([content, iv, "not base64!"], "--"), @right) == :error
  end
end
