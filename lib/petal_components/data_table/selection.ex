defmodule PetalComponents.DataTable.Selection do
  @moduledoc """
  The data table's selection grammar, applied to a plain list of row keys.

  Selection is UI state, not query state: it never rides the URL and
  never lives in `PetalComponents.DataTable.State`, so a link-mode
  `handle_params` rebuilding the state from params cannot wipe it, and
  it survives sorting, filtering and paging in both wiring modes.

      def handle_event("select", params, socket) do
        {:noreply, update(socket, :selected, &Selection.handle_op(&1, params))}
      end

  Ops (pushed by `<.data_table on_select=...>`):

    * `%{"op" => "select", "ids" => keys, "checked" => true}` - add `keys`
    * `%{"op" => "select", "ids" => keys, "checked" => false}` - remove them
    * `%{"op" => "clear_selection"}` - empty the selection

  A row checkbox posts its own key, the header checkbox posts every key
  on the visible page. `checked` is the target state rendered with the
  control, so a repeated push is idempotent rather than a double toggle.
  Keys arrive JSON-typed (integer ids stay integers). Unknown ops leave
  the selection unchanged.
  """

  @doc "Applies one selection op payload to the list of selected keys."
  def handle_op(selected, params) when is_list(selected) and is_map(params) do
    case params do
      %{"op" => "select", "ids" => ids, "checked" => checked} when is_list(ids) ->
        if checked in [true, "true"], do: select(selected, ids), else: deselect(selected, ids)

      %{"op" => "clear_selection"} ->
        []

      _other ->
        selected
    end
  end

  @doc "Adds `keys` to the selection, keeping order and uniqueness."
  def select(selected, keys) do
    present = MapSet.new(selected)
    selected ++ (keys |> Enum.uniq() |> Enum.reject(&MapSet.member?(present, &1)))
  end

  @doc "Removes `keys` from the selection."
  def deselect(selected, keys) do
    drop = MapSet.new(keys)
    Enum.reject(selected, &MapSet.member?(drop, &1))
  end
end
