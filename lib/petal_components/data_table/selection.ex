defmodule PetalComponents.DataTable.Selection do
  @moduledoc """
  Folds row-selection ops into the caller's selected-id list.

  Selection is not query state (it never round-trips through the URL),
  but it rides the same event as everything else so a handler stays two
  lines:

      def handle_event("table", %{"op" => op} = params, socket)
          when op in ~w(select select_page clear_selection) do
        selected = Selection.apply(socket.assigns.selected, params)
        {:noreply, assign(socket, selected: selected)}
      end

      def handle_event("table", params, socket) do
        state = State.handle_op(socket.assigns.table, params, fields: [:name])
        {:noreply, assign(socket, table: state)}
      end

  Ops:

    * `"select"` with `"id"` — toggle one row
    * `"select_page"` with `"mode"` `"all"` | `"none"` and `"ids"` a
      JSON list of the ids currently on the page
    * `"clear_selection"` — empty the list

  Anything else (sort, page, filter, …) returns the list unchanged, so
  it is safe to call `apply/2` unconditionally before `State.handle_op/3`.
  Ids already in the list keep whatever type the caller stored; ids
  arriving from the event are strings.
  """

  @doc "See the module docs."
  def apply(selected, params) when is_list(selected) and is_map(params) do
    case params do
      %{"op" => "select", "id" => id} ->
        toggle(selected, id)

      %{"op" => "select_page", "mode" => mode, "ids" => ids} when mode in ["all", "none"] ->
        apply_page(selected, mode, decode_ids(ids))

      %{"op" => "clear_selection"} ->
        []

      _other ->
        selected
    end
  end

  defp toggle(selected, id) do
    key = to_string(id)

    if Enum.any?(selected, &(to_string(&1) == key)) do
      Enum.reject(selected, &(to_string(&1) == key))
    else
      selected ++ [id]
    end
  end

  defp apply_page(selected, "all", ids) do
    have = MapSet.new(selected, &to_string/1)
    Enum.reduce(ids, selected, fn id, acc ->
      if to_string(id) in have, do: acc, else: acc ++ [id]
    end)
  end

  defp apply_page(selected, "none", ids) do
    drop = MapSet.new(ids, &to_string/1)
    Enum.reject(selected, &(to_string(&1) in drop))
  end

  defp decode_ids(ids) when is_list(ids), do: ids

  defp decode_ids(ids) when is_binary(ids) do
    case Jason.decode(ids) do
      {:ok, list} when is_list(list) -> list
      _ -> []
    end
  end

  defp decode_ids(_ids), do: []
end
