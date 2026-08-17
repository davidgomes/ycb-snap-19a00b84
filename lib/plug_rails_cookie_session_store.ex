defmodule PlugRailsCookieSessionStore do
  @moduledoc """
  Starting point: a straight copy of `Plug.Session.COOKIE`, the built-in
  cookie session store shipped with Plug. This module will be adapted to
  read and write session cookies in a format compatible with Ruby on
  Rails applications.

  Stores the session in a cookie.

  This cookie store is based on `Plug.Crypto.MessageVerifier` and
  `Plug.Crypto.MessageEncryptor` which encrypts and signs each cookie to
  ensure they can't be read nor tampered with.

  Since this store uses crypto features, it requires you to set the
  `:secret_key_base` field in your connection. This can be easily
  achieved with a plug:

      plug :put_secret_key_base

      def put_secret_key_base(conn, _) do
        put_in conn.secret_key_base, "-- LONG STRING WITH AT LEAST 64 BYTES --"
      end

  ## Options

    * `:encrypt` - specify whether to encrypt cookies, defaults to `true`.
      When this option is `false`, the cookie is still signed, meaning it
      cannot be tempered with but its contents can be read;

    * `:encryption_salt` - a salt used with `conn.secret_key_base` to generate
      a key for encrypting/decrypting a cookie, can be either a binary or
      an MFA returning a binary;

    * `:signing_salt` - a salt used with `conn.secret_key_base` to generate a
      key for signing/verifying a cookie, can be either a binary or an MFA
      returning a binary;

    * `:key_iterations` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 1000;

    * `:key_length` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to 32;

    * `:key_digest` - option passed to `Plug.Crypto.KeyGenerator`
      when generating the encryption and signing keys. Defaults to `:sha256`;

    * `:serializer` - cookie serializer module that defines `encode/1` and
      `decode/1` returning an `{:ok, value}` tuple. Defaults to
      `:external_term_format`.

  """

  @behaviour Plug.Session.Store

  def init(opts) do
    encryption_salt = check_encryption_salt(opts)
    signing_salt = check_signing_salt(opts)

    key_opts = Keyword.take(opts, [:iterations, :length, :digest, :cache])
    log = Keyword.get(opts, :log, :debug)

    serializer = check_serializer(Keyword.get(opts, :serializer, :external_term_format))

    %{
      encryption_salt: encryption_salt,
      signing_salt: signing_salt,
      key_opts: key_opts,
      log: log,
      serializer: serializer
    }
  end

  def get(conn, cookie, opts) do
    key_opts = opts.key_opts

    case opts do
      %{encryption_salt: nil} ->
        Plug.Crypto.verify(conn.secret_key_base, opts.signing_salt, cookie, key_opts)

      %{encryption_salt: encryption_salt} ->
        Plug.Crypto.decrypt(conn.secret_key_base, encryption_salt, cookie, key_opts)
    end
    |> decode(opts.serializer)
  end

  def put(conn, _sid, term, opts) do
    binary = encode(term, opts.serializer)

    key_opts = opts.key_opts

    case opts do
      %{encryption_salt: nil} ->
        Plug.Crypto.sign(conn.secret_key_base, opts.signing_salt, binary, key_opts)

      %{encryption_salt: encryption_salt} ->
        Plug.Crypto.encrypt(conn.secret_key_base, encryption_salt, binary, key_opts)
    end
  end

  def delete(_conn, _sid, _opts) do
    :ok
  end

  ## Helpers

  defp check_encryption_salt(opts) do
    case Keyword.fetch(opts, :encrypt) do
      {:ok, false} ->
        nil

      _ ->
        case Keyword.fetch(opts, :encryption_salt) do
          {:ok, salt} -> salt
          :error -> raise ArgumentError, "encryption_salt is a required option"
        end
    end
  end

  defp check_signing_salt(opts) do
    case Keyword.fetch(opts, :signing_salt) do
      {:ok, salt} -> salt
      :error -> raise ArgumentError, "signing_salt is a required option"
    end
  end

  defp check_serializer(:external_term_format), do: :external_term_format
  defp check_serializer(serializer) when is_atom(serializer), do: serializer

  defp decode(:error, _serializer), do: %{}

  defp decode({:ok, binary}, :external_term_format) do
    :erlang.binary_to_term(binary)
  end

  defp decode({:ok, binary}, serializer) do
    case serializer.decode(binary) do
      {:ok, term} -> term
      _ -> %{}
    end
  end

  defp encode(term, :external_term_format) do
    :erlang.term_to_binary(term)
  end

  defp encode(term, serializer) do
    {:ok, binary} = serializer.encode(term)
    binary
  end
end
