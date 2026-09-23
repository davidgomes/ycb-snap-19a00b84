defmodule Ocelot.HTML do
  @moduledoc false

  def escape({:safe, iodata}), do: IO.iodata_to_binary(iodata)
  def escape(nil), do: ""
  def escape(list) when is_list(list), do: Enum.map_join(list, &escape/1)
  def escape(binary) when is_binary(binary), do: Plug.HTML.html_escape(binary)
  def escape(value), do: value |> to_string() |> Plug.HTML.html_escape()
end
