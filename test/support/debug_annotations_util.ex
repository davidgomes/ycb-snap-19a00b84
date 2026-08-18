defmodule Surface.CompilerTest.DebugAnnotationsUtil do
  def debug_heex_annotations_supported? do
    vsn =
      Application.spec(:phoenix_live_view, :vsn)
      |> to_string()
      |> Version.parse!()

    Version.compare(vsn, "0.20.0") != :lt and Version.compare(vsn, "1.1.0") == :lt
  end
end
