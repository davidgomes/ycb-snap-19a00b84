defmodule Surface.Components.Utils do
  @moduledoc false

  @valid_uri_schemes [
    "http:",
    "https:",
    "ftp:",
    "ftps:",
    "mailto:",
    "news:",
    "irc:",
    "gopher:",
    "nntp:",
    "feed:",
    "telnet:",
    "mms:",
    "rtsp:",
    "svn:",
    "tel:",
    "fax:",
    "xmpp:"
  ]

  def valid_destination!(%URI{} = uri, context) do
    valid_destination!(URI.to_string(uri), context)
  end

  def valid_destination!({:safe, to}, context) do
    {:safe, valid_string_destination!(IO.iodata_to_binary(to), context)}
  end

  def valid_destination!({other, to}, _context) when is_atom(other) do
    [Atom.to_string(other), ?:, to]
  end

  def valid_destination!(to, context) do
    valid_string_destination!(IO.iodata_to_binary(to), context)
  end

  for scheme <- @valid_uri_schemes do
    def valid_string_destination!(unquote(scheme) <> _ = string, _context), do: string
  end

  def valid_string_destination!(to, context) do
    if not match?("/" <> _, to) and String.contains?(to, ":") do
      raise ArgumentError, """
      unsupported scheme given to #{context}. In case you want to link to an
      unknown or unsafe scheme, such as javascript, use a tuple: {:javascript, rest}
      """
    else
      to
    end
  end

  def csrf_data(to, opts) do
    case Keyword.pop(opts, :csrf_token, true) do
      {csrf, opts} when is_binary(csrf) ->
        {[csrf: csrf], opts}

      {true, opts} ->
        {[csrf: csrf_token(to)], opts}

      {false, opts} ->
        {[], opts}
    end
  end

  defp csrf_token(to) do
    {mod, fun, args} = Application.fetch_env!(:surface, :csrf_token_reader)
    apply(mod, fun, [to | args])
  end

  def skip_csrf(opts) do
    Keyword.delete(opts, :csrf_token)
  end
end
